function getRotationPrecomputeL(precompute_L, rotationMatrix){

	// rotationMatrix = mat4Matrix2mathMatrix(rotationMatrix);//将旋转矩阵转换为math中的数据结构
	let precompute_L_layer_1 = [];//第一阶的系数
	let precompute_L_layer_2 = [];//第二阶的系数
	let result = [];//旋转后的系数

	for (let i = 0; i < 3; i++){
		let r1 = [];
		let r2 = [];
		for (let j = 1; j < 4; j++){
			r1.push(precompute_L[i][j]);
		}
		for (let j = 4; j < 9; j++){
			r2.push(precompute_L[i][j]);
		}
		precompute_L_layer_1.push(r1);
		precompute_L_layer_2.push(r2);
	}
	let M1 = computeSquareMatrix_3by3(rotationMatrix);
	let M2 = computeSquareMatrix_5by5(rotationMatrix);
	for (let i = 0; i < 3; i++) {
		// let SH_rotation_1 = math.multiply(M1, [precompute_L[i][1], precompute_L[i][2], precompute_L[i][3]]);
		// let SH_rotation_2 = math.multiply(M2, [precompute_L[i][4], precompute_L[i][5], precompute_L[i][6],
		// 										precompute_L[i][7], precompute_L[i][8]]);
		let SH_rotation_1 = math.multiply(M1, precompute_L_layer_1[i]);
		let SH_rotation_2 = math.multiply(M2, precompute_L_layer_2[i]);

		result[i] = mat3.fromValues( precompute_L[i][0], SH_rotation_1._data[0], SH_rotation_1._data[1],
			SH_rotation_1._data[2], SH_rotation_2._data[0], SH_rotation_2._data[1],
			SH_rotation_2._data[2], SH_rotation_2._data[3], SH_rotation_2._data[4] );
	}

	return result;
}

function computeSquareMatrix_3by3(rotationMatrix){ // 计算方阵SA(-1) 3*3 
	
	// 1、pick ni - {ni}
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [0, 1, 0, 0];

	// 2、{P(ni)} - A  A_inverse
	let p1 = SHEval(n1[0], n1[1], n1[2], 3);
	let p2 = SHEval(n2[0], n2[1], n2[2], 3);
	let p3 = SHEval(n3[0], n3[1], n3[2], 3);
	let matrix_A = [];
	for(let i = 0; i < 3; i++){
		let r = [];
		r.push(p1[1 + i]);//取第1\2\3项为第二阶的系数
		r.push(p2[1 + i]);
		r.push(p3[1 + i]);
		matrix_A.push(r);
	}
	let A = math.matrix(matrix_A);
	// let matrix_A = math.matrix([[p1[1], p2[1], p3[1]],
	// 	[p1[2], p2[2], p3[2]],
	// 	[p1[3], p2[3], p3[3]]]);
	
	// let A = math.transpose(matrix_A);
	let A_inverse = math.inv(A);

	// 3、用 R 旋转 ni - {R(ni)}
	let n1R = vec4.create();
	let n2R = vec4.create();
	let n3R = vec4.create();
	vec4.transformMat4(n1R, n1, rotationMatrix);
	vec4.transformMat4(n2R, n2, rotationMatrix);
	vec4.transformMat4(n3R, n3, rotationMatrix);
	// let n1R = math.multiply(rotationMatrix, n1);
	// let n2R = math.multiply(rotationMatrix, n2);
	// let n3R = math.multiply(rotationMatrix, n3);

	// 4、R(ni) SH投影 - S
	let p1R = SHEval(n1R[0], n1R[1], n1R[2], 3);
	let p2R = SHEval(n2R[0], n2R[1], n2R[2], 3);
	let p3R = SHEval(n3R[0], n3R[1], n3R[2], 3);
	let matrix_S = [];
	for(let i = 0; i < 3; i++){
		let r = [];
		r.push(p1R[1 + i]);//取第1\2\3项为第二阶的系数
		r.push(p2R[1 + i]);
		r.push(p3R[1 + i]);
		matrix_S.push(r);
	}
	let S = math.matrix(matrix_S);
	// let matrix_S = math.matrix([[p1R[1], p2R[1], p3R[1]],
	// 	[p1R[2], p2R[2], p3R[2]],
	// 	[p1R[3], p2R[3], p3R[3]]]);
	// let S = math.transpose(matrix_S);
	let result = math.multiply(S, A_inverse);

	// 5、S*A_inverse
	return result;
}

function computeSquareMatrix_5by5(rotationMatrix){ // 计算方阵SA(-1) 5*5
	
	// 1、pick ni - {ni}
	let k = 1 / math.sqrt(2);
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [k, k, 0, 0]; 
	let n4 = [k, 0, k, 0]; let n5 = [0, k, k, 0];

	// 2、{P(ni)} - A  A_inverse
	let p1 = SHEval(n1[0], n1[1], n1[2], 3);
	let p2 = SHEval(n2[0], n2[1], n2[2], 3);
	let p3 = SHEval(n3[0], n3[1], n3[2], 3);
	let p4 = SHEval(n4[0], n4[1], n4[2], 3);
	let p5 = SHEval(n5[0], n5[1], n5[2], 3);
	let matrix_A = [];
	for(let i = 0; i < 5; i++){
		let r = [];
		r.push(p1[4 + i]);//取第4\5\6\7\8项为第三阶的系数
		r.push(p2[4 + i]);
		r.push(p3[4 + i]);
		r.push(p4[4 + i]);
		r.push(p5[4 + i]);
		matrix_A.push(r);
	}
	let A = math.matrix(matrix_A);
	// let matrix_A = math.matrix([[p1[4], p2[4], p3[4], p4[4], p5[4]],
	// 	[p1[5], p2[5], p3[5], p4[5], p5[5]],
	// 	[p1[6], p2[6], p3[6], p4[6], p5[6]],
	// 	[p1[7], p2[7], p3[7], p4[7], p5[7]],
	// 	[p1[8], p2[8], p3[8], p4[8], p5[8]]]);
	// let A = math.transpose(matrix_A);
	let A_inverse = math.inv(A);

	// 3、用 R 旋转 ni - {R(ni)}
	let n1R = vec4.create();
	let n2R = vec4.create();
	let n3R = vec4.create();
	let n4R = vec4.create();
	let n5R = vec4.create();
	vec4.transformMat4(n1R, n1, rotationMatrix);
	vec4.transformMat4(n2R, n2, rotationMatrix);
	vec4.transformMat4(n3R, n3, rotationMatrix);
	vec4.transformMat4(n4R, n4, rotationMatrix);
	vec4.transformMat4(n5R, n5, rotationMatrix);
	// let n1R = math.multiply(rotationMatrix, n1);
	// let n2R = math.multiply(rotationMatrix, n2);
	// let n3R = math.multiply(rotationMatrix, n3);
	// let n4R = math.multiply(rotationMatrix, n4);
	// let n5R = math.multiply(rotationMatrix, n5);

	// 4、R(ni) SH投影 - S
	let p1R = SHEval(n1R[0], n1R[1], n1R[2], 3);
	let p2R = SHEval(n2R[0], n2R[1], n2R[2], 3);
	let p3R = SHEval(n3R[0], n3R[1], n3R[2], 3);
	let p4R = SHEval(n4R[0], n4R[1], n4R[2], 3);
	let p5R = SHEval(n5R[0], n5R[1], n5R[2], 3);
	let matrix_S = [];
	for(let i = 0; i < 5; i++){
		let r = [];
		r.push(p1R[4 + i]);//取第4\5\6\7\8项为第三阶的系数
		r.push(p2R[4 + i]);
		r.push(p3R[4 + i]);
		r.push(p4R[4 + i]);
		r.push(p5R[4 + i]);
		matrix_S.push(r);
	}
	let S = math.matrix(matrix_S);
	// let matrix_S = math.matrix([[p1R[4], p2R[4], p3R[4], p4R[4], p5R[4]],
	// 	[p1R[5], p2R[5], p3R[5], p4R[5], p5R[5]],
	// 	[p1R[6], p2R[6], p3R[6], p4R[6], p5R[6]],
	// 	[p1R[7], p2R[7], p3R[7], p4R[7], p5R[7]],
	// 	[p1R[8], p2R[8], p3R[8], p4R[8], p5R[8]]]);
	// let S = math.transpose(matrix_S);
	let result = math.multiply(S, A_inverse);
	
	// 5、S*A_inverse
	return result;
}

function mat4Matrix2mathMatrix(rotationMatrix){

	let mathMatrix = [];
	for(let i = 0; i < 4; i++){
		let r = [];
		for(let j = 0; j < 4; j++){
			r.push(rotationMatrix[i*4+j]);
		}
		mathMatrix.push(r);
	}
	return math.matrix(mathMatrix)

}

function getMat3ValueFromRGB(precomputeL){

    let colorMat3 = [];
    for(var i = 0; i<3; i++){
        colorMat3[i] = mat3.fromValues( precomputeL[0][i], precomputeL[1][i], precomputeL[2][i],
										precomputeL[3][i], precomputeL[4][i], precomputeL[5][i],
										precomputeL[6][i], precomputeL[7][i], precomputeL[8][i] ); 
	}
    return colorMat3;
}