Shader "LINK/ShadowMapCaster"
{
    CGINCLUDE

    #include "UnityCG.cginc"

    struct a2v
    {
        float4 vertex : POSITION;
    };

    struct v2f
    {
        float4 vertex : SV_POSITION;
        float2 depth : TEXCOORD0;
    };

    v2f vert (a2v v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.depth = o.vertex.zw;//COMPUTE_DEPTH_01;
        return o;
    }

    half4 frag (v2f i) : SV_Target
    {
        half depth = i.depth.x / i.depth.y;
#if defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
        depth = depth * 0.5 + 0.5; //(-1, 1)-->(0, 1)
#elif defined (UNITY_REVERSED_Z)
        depth = 1 - depth;       //(1, 0)-->(0, 1)
#endif

#if (RFLOAT)
        half4 result = depth;
#elif (RGBA8)
        half4 result = EncodeFloatRGBA(depth);
#elif (RG16)
        half2 encode = EncodeFloatRG(depth);
        half4 result = half4(encode.xy, 0, 0);
#else
        half4 result = EncodeFloatRGBA(depth);
#endif
        return result;
    }

    ENDCG
    
    SubShader
    {
        Cull Back ZWrite On ZTest LEqual

        Tags
        {
            //"SigonoShadowMap"="1"
            //"RenderType"="Opaque"
            "LightMode" = "ForwardBase"
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ RFLOAT RGBA8 RG16
            ENDCG
        }
    }

    FallBack "Black"
}
