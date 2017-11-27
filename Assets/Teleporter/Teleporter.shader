// Geometry teleporter effect
// https://github.com/keijiro/GTeleporter

Shader "GTeleporter/Teleporter"
{
    Properties
    {
        _Color("Albedo", Color) = (0, 0, 0, 0)
        _MainTex("Albedo", 2D) = "white" {}
        _Glossiness("Smoothness", Range(0, 1)) = 0.5
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0

        [Header(Emission Colors)]
        [HDR] _Emission1("Primary", Color) = (0, 0, 0, 0)
        [HDR] _Emission2("Secondary", Color) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="Deferred" }
            CGPROGRAM
            #pragma target 4.0
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #pragma multi_compile_prepassfinal noshadowmask nodynlightmap nodirlightmap nolightmap
            #include "Teleporter.cginc"
            ENDCG
        }
        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            CGPROGRAM
            #pragma target 4.0
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #pragma multi_compile_prepassfinal noshadowmask nodynlightmap nodirlightmap nolightmap
            #define UNITY_PASS_SHADOWCASTER
            #include "Teleporter.cginc"
            ENDCG
        }
    }
}
