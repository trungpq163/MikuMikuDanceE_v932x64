xof 0302txt 0064
template Header {
 <3D82AB43-62DA-11cf-AB39-0020AF71E433>
 WORD major;
 WORD minor;
 DWORD flags;
}

template Vector {
 <3D82AB5E-62DA-11cf-AB39-0020AF71E433>
 FLOAT x;
 FLOAT y;
 FLOAT z;
}

template Coords2d {
 <F6F23F44-7686-11cf-8F52-0040333594A3>
 FLOAT u;
 FLOAT v;
}

template Matrix4x4 {
 <F6F23F45-7686-11cf-8F52-0040333594A3>
 array FLOAT matrix[16];
}

template ColorRGBA {
 <35FF44E0-6C7C-11cf-8F52-0040333594A3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
 FLOAT alpha;
}

template ColorRGB {
 <D3E16E81-7835-11cf-8F52-0040333594A3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
}

template IndexedColor {
 <1630B820-7842-11cf-8F52-0040333594A3>
 DWORD index;
 ColorRGBA indexColor;
}

template Boolean {
 <4885AE61-78E8-11cf-8F52-0040333594A3>
 WORD truefalse;
}

template Boolean2d {
 <4885AE63-78E8-11cf-8F52-0040333594A3>
 Boolean u;
 Boolean v;
}

template MaterialWrap {
 <4885AE60-78E8-11cf-8F52-0040333594A3>
 Boolean u;
 Boolean v;
}

template TextureFilename {
 <A42790E1-7810-11cf-8F52-0040333594A3>
 STRING filename;
}

template Material {
 <3D82AB4D-62DA-11cf-AB39-0020AF71E433>
 ColorRGBA faceColor;
 FLOAT power;
 ColorRGB specularColor;
 ColorRGB emissiveColor;
 [...]
}

template MeshFace {
 <3D82AB5F-62DA-11cf-AB39-0020AF71E433>
 DWORD nFaceVertexIndices;
 array DWORD faceVertexIndices[nFaceVertexIndices];
}

template MeshFaceWraps {
 <4885AE62-78E8-11cf-8F52-0040333594A3>
 DWORD nFaceWrapValues;
 Boolean2d faceWrapValues;
}

template MeshTextureCoords {
 <F6F23F40-7686-11cf-8F52-0040333594A3>
 DWORD nTextureCoords;
 array Coords2d textureCoords[nTextureCoords];
}

template MeshMaterialList {
 <F6F23F42-7686-11cf-8F52-0040333594A3>
 DWORD nMaterials;
 DWORD nFaceIndexes;
 array DWORD faceIndexes[nFaceIndexes];
 [Material]
}

template MeshNormals {
 <F6F23F43-7686-11cf-8F52-0040333594A3>
 DWORD nNormals;
 array Vector normals[nNormals];
 DWORD nFaceNormals;
 array MeshFace faceNormals[nFaceNormals];
}

template MeshVertexColors {
 <1630B821-7842-11cf-8F52-0040333594A3>
 DWORD nVertexColors;
 array IndexedColor vertexColors[nVertexColors];
}

template Mesh {
 <3D82AB44-62DA-11cf-AB39-0020AF71E433>
 DWORD nVertices;
 array Vector vertices[nVertices];
 DWORD nFaces;
 array MeshFace faces[nFaces];
 [...]
}

Header{
1;
0;
1;
}

Mesh {
 32;
 0.00000;0.01000;0.00000;,
 0.00433;0.00866;-0.00250;,
 0.00000;0.00866;-0.00500;,
 0.00433;0.00866;0.00250;,
 -0.00000;0.00866;0.00500;,
 -0.00433;0.00866;0.00250;,
 -0.00433;0.00866;-0.00250;,
 0.00750;0.00500;-0.00433;,
 0.00000;0.00500;-0.00866;,
 0.00750;0.00500;0.00433;,
 -0.00000;0.00500;0.00866;,
 -0.00750;0.00500;0.00433;,
 -0.00750;0.00500;-0.00433;,
 0.00866;-0.00000;-0.00500;,
 0.00000;-0.00000;-0.01000;,
 0.00866;-0.00000;0.00500;,
 -0.00000;-0.00000;0.01000;,
 -0.00866;-0.00000;0.00500;,
 -0.00866;-0.00000;-0.00500;,
 0.00750;-0.00500;-0.00433;,
 0.00000;-0.00500;-0.00866;,
 0.00750;-0.00500;0.00433;,
 -0.00000;-0.00500;0.00866;,
 -0.00750;-0.00500;0.00433;,
 -0.00750;-0.00500;-0.00433;,
 0.00433;-0.00866;-0.00250;,
 0.00000;-0.00866;-0.00500;,
 0.00433;-0.00866;0.00250;,
 -0.00000;-0.00866;0.00500;,
 -0.00433;-0.00866;0.00250;,
 -0.00433;-0.00866;-0.00250;,
 0.00000;-0.01000;-0.00000;;
 
 36;
 3;0,1,2;,
 3;0,3,1;,
 3;0,4,3;,
 3;0,5,4;,
 3;0,6,5;,
 3;0,2,6;,
 4;2,1,7,8;,
 4;1,3,9,7;,
 4;3,4,10,9;,
 4;4,5,11,10;,
 4;5,6,12,11;,
 4;6,2,8,12;,
 4;8,7,13,14;,
 4;7,9,15,13;,
 4;9,10,16,15;,
 4;10,11,17,16;,
 4;11,12,18,17;,
 4;12,8,14,18;,
 4;14,13,19,20;,
 4;13,15,21,19;,
 4;15,16,22,21;,
 4;16,17,23,22;,
 4;17,18,24,23;,
 4;18,14,20,24;,
 4;20,19,25,26;,
 4;19,21,27,25;,
 4;21,22,28,27;,
 4;22,23,29,28;,
 4;23,24,30,29;,
 4;24,20,26,30;,
 3;26,25,31;,
 3;25,27,31;,
 3;27,28,31;,
 3;28,29,31;,
 3;29,30,31;,
 3;30,26,31;;
 
 MeshMaterialList {
  1;
  36;
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0;;
  Material {
   0.800000;0.800000;0.800000;1.000000;;
   5.000000;
   0.000000;0.000000;0.000000;;
   0.000000;0.000000;0.000000;;
  }
 }
}
