// Geometry teleporter effect
// https://github.com/keijiro/GTeleporter

#include "Common.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardUtils.cginc"
#include "SimplexNoise3D.hlsl"

// Cube map shadow caster; Used to render point light shadows on platforms
// that lacks depth cube map support.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define PASS_CUBE_SHADOWCASTER
#endif

// Base properties
half4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
half _Glossiness;
half _Metallic;

// Effect properties
half3 _Emission1;
half3 _Emission2;

// Dynamic properties
float4 _EffectVector;
float3 _EffectPoint;

// Vertex input attributes
struct Attributes
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD;
};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass
    float3 shadow : TEXCOORD0;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass

#else
    // GBuffer construction pass
    half3 normal : NORMAL;
    float2 texcoord : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    half3 ambient : TEXCOORD2;
    half3 emission : COLOR;

#endif
};

//
// Vertex stage
//

void Vertex(inout Attributes input)
{
    // Only do object space to world space transform.
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
}

//
// Geometry stage
//

Varyings VertexOutput(float3 wpos, half3 wnrm, float2 uv, half3 emission)
{
    Varyings o;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass: Transfer the shadow vector.
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.shadow = wpos - _LightPositionRange.xyz;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass: Apply the shadow bias.
    float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos)));
    wpos -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
    o.position = UnityApplyLinearShadowBias(UnityWorldToClipPos(float4(wpos, 1)));

#else
    // GBuffer construction pass
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.normal = wnrm;
    o.texcoord = uv;
    o.worldPos = wpos;
    o.ambient = ShadeSHPerVertex(wnrm, 0);
    o.emission = emission;

#endif
    return o;
}

[maxvertexcount(6)]
void Geometry(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    // Input vertices
    float3 p0 = input[0].position.xyz;
    float3 p1 = input[1].position.xyz;
    float3 p2 = input[2].position.xyz;

    float3 n0 = input[0].normal;
    float3 n1 = input[1].normal;
    float3 n2 = input[2].normal;

    float2 uv0 = input[0].texcoord;
    float2 uv1 = input[1].texcoord;
    float2 uv2 = input[2].texcoord;

    float3 center = (p0 + p1 + p2) / 3;

    // Deformation parameter
    float param = 1 - dot(_EffectVector.xyz, center) + _EffectVector.w;

    // Pass through the vertices if the deformation hasn't been started yet.
    if (param < 0)
    {
        outStream.Append(VertexOutput(p0, n0, uv0, 0));
        outStream.Append(VertexOutput(p1, n1, uv1, 0));
        outStream.Append(VertexOutput(p2, n2, uv2, 0));
        outStream.RestartStrip();
        return;
    }

    // Draw nothing at the end of the deformation.
    if (param >= 1) return;

    // We use smoothstep to make naturally damped linear motion.
    float ss_param = smoothstep(0, 1, param);

    uint seed = pid * 877;
    if (Random(seed) < 0.3)
    {
        // Triangle vertices at the relay point
        float3 rp0 = center + snoise_grad(center * 1.3).xyz * 0.3;
        float3 rp1 = rp0 + RandomUnitVector(seed + 3) * 0.02;
        float3 rp2 = rp0 + RandomUnitVector(seed + 5) * 0.02;

        // Vanishing point
        float3 rv = _EffectPoint + RandomVector(seed + 7) * 0.3;
        rv.y = center.y;

        // Parameter value at the midpoint
        float m0 = 0.4 + Random(seed + 9) * 0.3;
        float m1 = m0 + (Random(seed + 10) - 0.5) * 0.2;
        float m2 = m0 + (Random(seed + 11) - 0.5) * 0.2;

        // Initial inflation animation
        float3 t_p0 = p0 + (p0 - center) * 4 * smoothstep(0, 0.05, param);
        float3 t_p1 = p1 + (p1 - center) * 4 * smoothstep(0, 0.05, param);
        float3 t_p2 = p2 + (p2 - center) * 4 * smoothstep(0, 0.05, param);

        // Move to the relay point.
        t_p0 = lerp(t_p0, rp0, smoothstep(0.05, m0, param));
        t_p1 = lerp(t_p1, rp1, smoothstep(0.05, m1, param));
        t_p2 = lerp(t_p2, rp2, smoothstep(0.05, m2, param));

        // Move to the vanishing point.
        t_p0 = lerp(t_p0, rv, smoothstep(m0 * 0.75, 1, param));
        t_p1 = lerp(t_p1, rv, smoothstep(m1 * 0.75, 1, param));
        t_p2 = lerp(t_p2, rv, smoothstep(m2 * 0.75, 1, param));

        // Recalculate the normal vector.
        float3 normal = normalize(cross(t_p1 - t_p0, t_p2 - t_p0));

        // Material animation
        float3 em = lerp(_Emission1, _Emission2, Random(seed + 12));
        em *= smoothstep(0.2, 0.5, param);

        // Vertex outputs
        outStream.Append(VertexOutput(t_p0, normal, uv0, em));
        outStream.Append(VertexOutput(t_p1, normal, uv1, em));
        outStream.Append(VertexOutput(t_p2, normal, uv2, em));
        outStream.RestartStrip();

        outStream.Append(VertexOutput(t_p0, -normal, uv0, em));
        outStream.Append(VertexOutput(t_p2, -normal, uv2, em));
        outStream.Append(VertexOutput(t_p1, -normal, uv1, em));
        outStream.RestartStrip();
    }
    else
    {
        // Random motion
        float3 move = RandomVector(seed + 1) * ss_param * 0.5;

        // Random rotation
        float3 rot_angles = (RandomVector01(seed + 1) - 0.5) * 100;
        float3x3 rot_m = Euler3x3(rot_angles * ss_param);

        // Simple shrink
        float scale = 1 - ss_param;

        // Apply the animation.
        float3 t_p0 = mul(rot_m, p0 - center) * scale + center + move;
        float3 t_p1 = mul(rot_m, p1 - center) * scale + center + move;
        float3 t_p2 = mul(rot_m, p2 - center) * scale + center + move;
        float3 normal = normalize(cross(t_p1 - t_p0, t_p2 - t_p0));

        // Material animation
        float3 em = lerp(_Emission1, _Emission2, Random(seed + 12));
        em *= smoothstep(0, 0.1, param) * smoothstep(0.3, 0.9, 1 - param);

        // Vertex outputs
        outStream.Append(VertexOutput(t_p0, normal, uv0, em));
        outStream.Append(VertexOutput(t_p1, normal, uv1, em));
        outStream.Append(VertexOutput(t_p2, normal, uv2, em));
        outStream.RestartStrip();

        outStream.Append(VertexOutput(t_p0, -normal, uv0, em));
        outStream.Append(VertexOutput(t_p2, -normal, uv2, em));
        outStream.Append(VertexOutput(t_p1, -normal, uv1, em));
        outStream.RestartStrip();
    }
}

//
// Fragment phase
//

#if defined(PASS_CUBE_SHADOWCASTER)

// Cube map shadow caster pass
half4 Fragment(Varyings input) : SV_Target
{
    float depth = length(input.shadow) + unity_LightShadowBias.x;
    return UnityEncodeCubeShadowDepth(depth * _LightPositionRange.w);
}

#elif defined(UNITY_PASS_SHADOWCASTER)

// Default shadow caster pass
half4 Fragment() : SV_Target { return 0; }

#else

// GBuffer construction pass
void Fragment(
    Varyings input,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
)
{
    half3 albedo = tex2D(_MainTex, input.texcoord).rgb * _Color.rgb;

    // PBS workflow conversion (metallic -> specular)
    half3 c_diff, c_spec;
    half not_in_use;

    c_diff = DiffuseAndSpecularFromMetallic(
        albedo, _Metallic, // input
        c_spec, not_in_use // output
    );

    // Update the GBuffer.
    UnityStandardData data;
    data.diffuseColor = c_diff;
    data.occlusion = 1;
    data.specularColor = c_spec;
    data.smoothness = _Glossiness;
    data.normalWorld = input.normal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Output ambient light and edge emission to the emission buffer.
    half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient, input.worldPos);
    outEmission = half4(sh * data.diffuseColor + input.emission, 1);
}

#endif
