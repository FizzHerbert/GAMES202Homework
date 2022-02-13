attribute vec3 aVertexPosition;
attribute mat3 aPrecomputeLT;

uniform mat3 uPrecomputeLR;//场景光中红色分量的球谐函数系数
uniform mat3 uPrecomputeLG;//场景光中绿色分量的球谐函数系数
uniform mat3 uPrecomputeLB;//场景光中蓝色分量的球谐函数系数

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

// varying highp mat3 vPrecomputeLT;
varying highp vec3 vColor;

void main(void) {
    gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition, 1.0);

    vColor = vec3(0.0, 0.0, 0.0);
    for (int i = 0; i < 3; i++)
    {
        vColor = vColor + vec3(uPrecomputeLR[i][0], uPrecomputeLG[i][0], uPrecomputeLB[i][0]) * aPrecomputeLT[i][0];
        vColor = vColor + vec3(uPrecomputeLR[i][1], uPrecomputeLG[i][1], uPrecomputeLB[i][1]) * aPrecomputeLT[i][1];
        vColor = vColor + vec3(uPrecomputeLR[i][2], uPrecomputeLG[i][2], uPrecomputeLB[i][2]) * aPrecomputeLT[i][2];
    }
    // vColor = vColor / vec3(3.14159265758);
}