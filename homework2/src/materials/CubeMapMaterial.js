class CubeMapMaterial extends Material {

    constructor(vertexShader, fragmentShader) {
        super({
            'uPrecomputeLR': { type: 'updatedInRealTime', value: null },
            'uPrecomputeLG': { type: 'updatedInRealTime', value: null },
            'uPrecomputeLB': { type: 'updatedInRealTime', value: null }
            // 'uSampler' : { type: 'texture', value: color }
        }, ['aPrecomputeLT'], vertexShader, fragmentShader, null);
    }
}

async function buildCubeMapMaterial(vertexPath, fragmentPath) {


    let vertexShader = await getShaderString(vertexPath);
    let fragmentShader = await getShaderString(fragmentPath);

    return new CubeMapMaterial(vertexShader, fragmentShader);

}