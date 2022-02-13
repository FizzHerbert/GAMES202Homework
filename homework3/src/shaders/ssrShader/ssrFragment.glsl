#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 L = vec3(0.0);
  vec3 reflectivity = GetGBufferDiffuse(uv);
  vec3 N = normalize(GetGBufferNormalWorld(uv));

  if(dot(wi, N) > 0.0)//在背面半球无反射光(dot(wo, N) > 0.0)
  {
    L = reflectivity * INV_PI * dot(wi, N);//因为是计算radiance，所以需要考虑入射角与法线夹角产生的实际光线能量
  }
  // L = reflectivity * INV_PI;
  

  return L;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  vec3 Le = vec3(0.0);
  float visibility = GetGBufferuShadow(uv);//注意这里已经是和shadowmap比较过的逻辑值了

  // Le = visibility * uLightRadiance;
  if (visibility > 0.0)
  {
    Le = uLightRadiance;
  }
  // else
  // {
  //   Le = vec3(1.0, 0.0, 0.0);
  // }

  return Le;
}

bool outScreen(vec2 uv) {
  return any(bvec4(lessThan(uv, vec2(0.0)), greaterThan(uv, vec2(1.0))));//如果出界了，就返回true
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  //ori起点
  //dir光线发射方向
  //hitPos如果和场景有交点，交点位置
  vec3 curPos = ori;
  vec3 prePos = ori;
  float stepLen = 0.8;
  float curDepth;//当前点的深度
  float ssDepth;//屏幕空间中对应点的深度
  bool isHit = false;

  for (int i = 0; i < 20; i++)
  {
    curPos = curPos + stepLen * dir;
    if (outScreen(GetScreenCoordinate(prePos)) == true)//出了屏幕空间，改变步长
    {
      break;
    }
    ssDepth = GetGBufferDepth(GetScreenCoordinate(curPos));//获取屏幕空间中对应点到相机的深度
    curDepth = GetDepth(curPos);//获取当前点到相机的深度
    if (curDepth >= ssDepth)//说明有相交
    {
        curPos = prePos;//在洞穴这个场景中，不能让交点在屏幕空间的着色点的后方，否则shadowmap会认为被挡住
        stepLen *= 0.5;
    }
    else//说明未相交
    {
      if ((ssDepth - curDepth) < 0.05)//认为是交点
      {
        hitPos = curPos;
        isHit = true;
        break;
      }
      else
      {
        prePos = curPos;
        stepLen *= 2.0;//对step加倍
      }
    }
  }

  return isHit;
}

#define SAMPLE_NUM 10

void main() {
  float s = InitRand(gl_FragCoord.xy);
  float pdf = 0.0;
  vec2 uv = GetScreenCoordinate(vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);//入射方向，注意起点为着色点
  vec3 wo = normalize(uCameraPos - gl_FragCoord.xyz);//出射方向
  vec3 normal = normalize(GetGBufferNormalWorld(uv));
  vec3 L = vec3(0.0);
  vec3 b1 = vec3(0.0);
  vec3 b2 = vec3(0.0);
  LocalBasis(normal, b1, b2);

  L = EvalDiffuse(wi, wo, uv) * EvalDirectionalLight(uv);
  // L = EvalDiffuse(wi, wo, uv);
  // L = EvalDirectionalLight(uv);
  // L = GetGBufferDiffuse(uv);

  vec3 L_indirect = vec3(0.0);
  for (int i = 0; i < SAMPLE_NUM; i++)
  {
    vec3 direction = vec3(0.0);
    vec3 hitPos = vec3(0.0);

    // s = Rand1(s);
    direction = SampleHemisphereCos(s, pdf);
    // direction = SampleHemisphereUniform(s, pdf);
    direction = normalize(mat3(b1, b2, normal) * direction);//注意采样出来的方向是局部坐标，要转换为世界坐标
    if (RayMarch(vPosWorld.xyz, direction, hitPos))//注意这里要用vPosWorld而不是gl_FragCoord.xyz，否则计算textureCoord时会出界导致结果为0
    {
      vec3 wo_hitPos = -direction;
      vec3 wi_hitPos = wi;//原光照方向
      wi = direction;//因为间接光照的入射光方向不是方向光源的方向，需要重新计算
      vec2 uv_hitPos = GetScreenCoordinate(hitPos);
      vec3 L_addition = vec3(uv_hitPos, 1.0);//本次采样间接光的增量
      // L_addition = EvalDirectionalLight(uv_hitPos);
      // L_addition = EvalDiffuse(wi_hitPos, wo_hitPos, uv_hitPos);
      // L_addition = EvalDiffuse(wi, wo, uv);
      L_addition = EvalDiffuse(wi_hitPos, wo_hitPos, uv_hitPos) * EvalDirectionalLight(uv_hitPos);
      L_addition = L_addition * EvalDiffuse(wi, wo, uv);
      L_addition = L_addition / pdf;
      L_indirect = L_indirect + L_addition;
    }
  }
  L_indirect = L_indirect * TWO_PI / float(SAMPLE_NUM);

  vec3 color = pow(clamp(L + L_indirect, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}