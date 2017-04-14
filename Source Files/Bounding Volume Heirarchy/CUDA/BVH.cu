#include "BVH.cuh"
#include "Utility\CUDA\CUDAHelper.cuh"
#include "Utility/Logger.h"

BVH::BVH() {

	currentSize = 0;
	allocatedSize = 0;

	bvh = nullptr;

	CudaCheck(cudaMalloc((void**)&rootDevice, sizeof(Node)));
}

BVH::~BVH() {
	if (bvh) {
		CudaCheck(cudaFree(bvh));
	}

	CudaCheck(cudaFree(rootDevice));

}

// Returns the highest differing bit of i and i+1
__device__ uint HighestBit(uint i, uint64* morton)
{
	return morton[i] ^ morton[i + 1];
}

__global__ void BuildTree(const uint n, Node* nodes, uint64* mortonCodes, const uint leafOffset, Node** root)
{
	uint index = getGlobalIdx_1D_1D();
	if (index >= n)
		return;

	Node* currentNode = nodes + (leafOffset + index);

	while (true) {
		// Allow only one thread to process a node
		if (atomicAdd(&(currentNode->atomic), 1) != 1)
			return;

		// Set bounding box if the node is no leaf
		if (currentNode - nodes < leafOffset)
		{
			currentNode->box.max = glm::max(currentNode->childLeft->box.max, currentNode->childRight->box.max);
			currentNode->box.min = glm::min(currentNode->childLeft->box.min, currentNode->childRight->box.min);
		}

		uint left = currentNode->rangeLeft;
		uint right = currentNode->rangeRight;

		if (left == 0 && right == leafOffset) {
			*root = currentNode;
			return;
		}

		Node* parent;
		if (left == 0 || (right < leafOffset && HighestBit(left - 1, mortonCodes) > HighestBit(right, mortonCodes)))
		{
			// parent = right, set parent left child and range to node
			parent = nodes + right;
			parent->childLeft = currentNode;
			parent->rangeLeft = left;

		}
		else
		{
			// parent = left -1, set parent right child and range to node
			parent = nodes + (left - 1);
			parent->childRight = currentNode;
			parent->rangeRight = right;
		}

		currentNode = parent;
	}
}


__global__ void Reset(const uint n, Node* nodes, Face* faces, Vertex* vertices, uint64* mortonCodes, const uint leafOffset)
{
	uint index = getGlobalIdx_1D_1D();

	if (index >= n) {
		return;
	}

	// Set ranges
	nodes[leafOffset + index].rangeLeft = index;
	nodes[leafOffset + index].rangeRight = index;
	nodes[leafOffset + index].atomic = 1; // To allow the next thread to process
	nodes[leafOffset + index].childLeft = nullptr; // Second thread to process
	nodes[leafOffset + index].childRight = nullptr; // Second thread to process
	if (index < leafOffset) {
		/*nodes[index].rangeLeft = index;   //unneeded as all nodes are touched and updated
		nodes[index].rangeRight = index + 1;*/
		nodes[index].atomic = 0; // Second thread to process
		nodes[index].childLeft = &nodes[leafOffset + index]; // Second thread to process
		nodes[index].childRight = &nodes[leafOffset + index + 1]; // Second thread to process
	}


	// Set triangles in leaf
	Face face = faces[index];
	nodes[leafOffset + index].faceID = index;

	// Expand bounds using min/max functions

	glm::vec3 max = vertices[face.indices.x].position;
	glm::vec3 min = vertices[face.indices.x].position;

	max = glm::max(vertices[face.indices.y].position, max);
	min = glm::min(vertices[face.indices.y].position, min);

	max = glm::max(vertices[face.indices.z].position, max);
	min = glm::min(vertices[face.indices.z].position, min);

	nodes[leafOffset + index].box.max = max;
	nodes[leafOffset + index].box.min = min;

	// Special case
	if (n == 1)
	{
		nodes[0].box = nodes[leafOffset + 0].box;
		nodes[0].childLeft = &nodes[leafOffset + 0];
	}
}

void BVH::Build(uint size, uint64* mortonCodes, Face * faces, Vertex * vertices) {

	currentSize = size;

	if (currentSize > 0) {
		if (currentSize > allocatedSize) {

			Node* nodeTemp;

			allocatedSize = glm::max(uint(allocatedSize * 1.5f), (currentSize * 2) - 1);


			CudaCheck(cudaMalloc((void**)&nodeTemp, allocatedSize * sizeof(Node)));
			if (bvh) {
				CudaCheck(cudaFree(bvh));
			}
			bvh = nodeTemp;
		}

		root = bvh;

		uint blockSize = 64;
		uint gridSize = (currentSize + blockSize - 1) / blockSize;

		CudaCheck(cudaDeviceSynchronize());

		Reset << <gridSize, blockSize >> > (currentSize, bvh, faces, vertices, mortonCodes, currentSize - 1);
		CudaCheck(cudaPeekAtLastError());
		CudaCheck(cudaDeviceSynchronize());


		//copy 'this' into the kernal
		CudaCheck(cudaMemcpy(rootDevice, &root, sizeof(Node), cudaMemcpyHostToDevice));

		BuildTree << <gridSize, blockSize >> > (currentSize, bvh, mortonCodes, currentSize - 1, rootDevice);

		CudaCheck(cudaPeekAtLastError());
		CudaCheck(cudaDeviceSynchronize());

		CudaCheck(cudaMemcpy(&root, rootDevice, sizeof(Node), cudaMemcpyDeviceToHost));

		//Node* nodeHost = new Node[currentSize*2-1];
		//CudaCheck(cudaMemcpy(nodeHost, bvh, (currentSize * 2 - 1) * sizeof(Node), cudaMemcpyDeviceToHost));

		//Node newRoot;
		//CudaCheck(cudaMemcpy(newRoot, root, (currentSize * 2 - 1) * sizeof(Node), cudaMemcpyDeviceToHost));


		//std::cout << "Nodes" << std::endl;
		//for (int i = 0; i < currentSize - 1; i++) {
		//	std::cout << nodeHost[i].childLeft- bvh <<" -L, ";
		//	std::cout << nodeHost[i].childRight- bvh << " -R, ";

		//}
		//std::cout << std::endl;

		//std::cout << "Faces" << std::endl;
		//for (int i = currentSize - 1; i < currentSize * 2 - 1; i++) {
		//	std::cout << nodeHost[i].faceID << ", ";
		//}
	}
	else {
		root = nullptr;
	}

}