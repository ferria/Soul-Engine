#include "Object.cuh"
#include "Utility\CUDA\CUDAHelper.cuh"

#define TINYOBJLOADER_IMPLEMENTATION
#include <tiny_obj_loader.h>

#include <unordered_map>
Object::Object(){

	verticeAmount = 0;
	faceAmount = 0;
	materialSize = 0;
	localSceneIndex = 0;
	ready = false;

	xyzPosition = glm::vec3(0);

	vertices = NULL;
	faces = NULL;
	materialP = NULL;
}
Object::Object(glm::vec3 pos, std::string name, Material* mat){

	verticeAmount = 0;
	faceAmount = 0;
	materialSize = 1;
	localSceneIndex = 0;
	ready = false;

	xyzPosition = glm::vec3(0);

	vertices = NULL;
	faces = NULL;
	CudaCheck(cudaMallocManaged((void**)&materialP, materialSize*sizeof(Material*)));
	materialP[0] = mat;

	xyzPosition = pos;
	ExtractFromFile(name.c_str());
}

void Object::AddVertices(Vertex* vertices, uint vSize){

}
void Object::AddFaces(Face* vertices, uint fSize){

}
void Object::ExtractFromFile(const char* name){



	tinyobj::attrib_t attrib;
	std::vector<tinyobj::shape_t> shapes;
	std::vector<tinyobj::material_t> materials;
	std::string err;

	if (!tinyobj::LoadObj(&attrib, &shapes, &materials, &err, name)) {
		throw std::runtime_error(err);
	}

	assert(shapes.size() == 1);

	verticeAmount = attrib.vertices.size() / 3;
	faceAmount = shapes[0].mesh.indices.size() / 3;

	glm::vec3 max = glm::vec3(attrib.vertices[0], attrib.vertices[1], attrib.vertices[2]);
	glm::vec3 min = max;

	cudaDeviceSynchronize();

	CudaCheck(cudaMallocManaged((void**)&vertices,
		verticeAmount*sizeof(Vertex)));

	CudaCheck(cudaMallocManaged((void**)&faces,
		faceAmount*sizeof(Face)));

	cudaDeviceSynchronize();



	std::unordered_map<Vertex, int> uniqueVertices = {};

	const auto& shape = shapes[0];

	for (size_t f = 0; f < shape.mesh.indices.size() / 3; f++) {


		//grab commenly used variables
		tinyobj::index_t id0 = shape.mesh.indices[3 * f + 0];
		tinyobj::index_t id1 = shape.mesh.indices[3 * f + 1];
		tinyobj::index_t id2 = shape.mesh.indices[3 * f + 2];

		int current_material_id = shape.mesh.material_ids[f];

		faces[f].indices.x = id0.vertex_index;
		vertices[id0.vertex_index].position.x = attrib.vertices[id0.vertex_index * 3 + 0];
		vertices[id0.vertex_index].position.y = attrib.vertices[id0.vertex_index * 3 + 1];
		vertices[id0.vertex_index].position.z = attrib.vertices[id0.vertex_index * 3 + 2];

		vertices[id0.vertex_index].textureCoord.x = attrib.texcoords[id0.texcoord_index * 2 + 0];
		vertices[id0.vertex_index].textureCoord.y = 1.0f - attrib.texcoords[id0.texcoord_index * 2 + 1];

		vertices[id0.vertex_index].normal.x = attrib.normals[id0.normal_index * 3 + 0];
		vertices[id0.vertex_index].normal.y = attrib.normals[id0.normal_index * 3 + 1];
		vertices[id0.vertex_index].normal.z = attrib.normals[id0.normal_index * 3 + 2];

		vertices[id0.vertex_index].position += xyzPosition;
		max = glm::max(vertices[id0.vertex_index].position, max);
		min = glm::min(vertices[id0.vertex_index].position, min);

		///////////////////

		faces[f].indices.y = id1.vertex_index;
		vertices[id1.vertex_index].position.x = attrib.vertices[id1.vertex_index * 3 + 0];
		vertices[id1.vertex_index].position.y = attrib.vertices[id1.vertex_index * 3 + 1];
		vertices[id1.vertex_index].position.z = attrib.vertices[id1.vertex_index * 3 + 2];

		vertices[id1.vertex_index].textureCoord.x = attrib.texcoords[id1.texcoord_index * 2 + 0];
		vertices[id1.vertex_index].textureCoord.y = 1.0f - attrib.texcoords[id1.texcoord_index * 2 + 1];

		vertices[id1.vertex_index].normal.x = attrib.normals[id1.normal_index * 3 + 0];
		vertices[id1.vertex_index].normal.y = attrib.normals[id1.normal_index * 3 + 1];
		vertices[id1.vertex_index].normal.z = attrib.normals[id1.normal_index * 3 + 2];

		vertices[id1.vertex_index].position += xyzPosition;
		max = glm::max(vertices[id1.vertex_index].position, max);
		min = glm::min(vertices[id1.vertex_index].position, min);

		///////////////////

		faces[f].indices.z = id2.vertex_index;
		vertices[id2.vertex_index].position.x = attrib.vertices[id2.vertex_index * 3 + 0];
		vertices[id2.vertex_index].position.y = attrib.vertices[id2.vertex_index * 3 + 1];
		vertices[id2.vertex_index].position.z = attrib.vertices[id2.vertex_index * 3 + 2];

		vertices[id2.vertex_index].textureCoord.x = attrib.texcoords[id2.texcoord_index * 2 + 0];
		vertices[id2.vertex_index].textureCoord.y = 1.0f - attrib.texcoords[id2.texcoord_index * 2 + 1];

		vertices[id2.vertex_index].normal.x = attrib.normals[id2.normal_index * 3 + 0];
		vertices[id2.vertex_index].normal.y = attrib.normals[id2.normal_index * 3 + 1];
		vertices[id2.vertex_index].normal.z = attrib.normals[id2.normal_index * 3 + 2];

		vertices[id2.vertex_index].position += xyzPosition;
		max = glm::max(vertices[id2.vertex_index].position, max);
		min = glm::min(vertices[id2.vertex_index].position, min);

		faces[f].materialPointer = materialP[0];
	}




	//std::cout << "\nINDICES: " << faceAmount << std::endl;
	//for (int i = 0; i < faceAmount; i++){
	//	printf("%i ", faces[i].indices.x);
	//	printf("%i ", faces[i].indices.y);
	//	printf("%i \n", faces[i].indices.z);
	//}

	//std::cout << "\nVERTICES: " << verticeAmount << std::endl;

	//for (int i = 0; i < verticeAmount; i++){
	//	std::cout << "\n	Positions: "  << std::endl;

	//	printf("%f ", vertices[i].position.x);
	//	printf("%f ", vertices[i].position.y);
	//	printf("%f \n", vertices[i].position.z);

	//	std::cout << "\n	Normals: " << std::endl;

	//	printf("%f ", vertices[i].normal.x);
	//	printf("%f ", vertices[i].normal.y);
	//	printf("%f \n", vertices[i].normal.z);

	//	std::cout << "\n	TexCoords: " << std::endl;

	//	printf("%f ", vertices[i].textureCoord.x);
	//	printf("%f \n", vertices[i].textureCoord.y);
	//}

	box.max = max;
	box.min = min;
	cudaDeviceSynchronize();

}