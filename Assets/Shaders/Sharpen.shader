Shader "LINK/Post-Process/Sharpen"
{
    Properties
    {
        _Params ("Strength (X) Clamp (Y) Pixel Size (ZW)", Vector) = (0.60, 0.05, 1, 1)
    }

    HLSLINCLUDE

    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/Colors.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
    float2 _MainTex_TexelSize;
    uniform float4 _Params;
    uniform float _Threshold = 0.01;
    uniform float _Edge = 1;
    uniform float _ContrastThreshold = 0.0312;
    uniform float _RelativeThreshold = 0.063;
    uniform float _CompareSlider = 1;

    struct LuminanceData
    {
        float m, n, e, s, w;
        float ne, nw, se, sw;
        float highest, lowest, contrast;
    };

    struct EdgeData
    {
        bool isHorizontal;
        float pixelStep;
    };

    float DecodeFloatRG( float2 enc )
    {
	    float2 kDecodeDot = float2(1.0, 1.0/255.0);
	    return dot( enc, kDecodeDot );
    }

    float3 DecodeViewNormal( float4 enc4 )
    {
	    float kScale = 1.7777;
	    float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
	    float g = 2.0 / dot(nn.xyz,nn.xyz);
	    float3 n;
	    n.xy = g*nn.xy;
	    n.z = g-1;
	    return n;
    }

    void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
    {
	    depth = DecodeFloatRG (enc.zw);
	    normal = DecodeViewNormal(enc);
    }

    float4 GetPixelValue(in float2 uv)
    {
        half3 normal;
        float depth;
        float4 depthnormal = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
        DecodeDepthNormal(depthnormal, depth, normal);
        return float4(normal, depth);
    }

    float SampleLuminance(float2 uv, float uOffset, float vOffset)
    {
        uv += _MainTex_TexelSize * float2(uOffset, vOffset);
        float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
        return Luminance(color.rgb);
    }

    LuminanceData SampleLuminanceNeighborhood(float2 uv)
    {
		LuminanceData l;
		l.m = SampleLuminance(uv,  0,  0);
		l.n = SampleLuminance(uv,  0,  1);
		l.e = SampleLuminance(uv,  1,  0);
		l.s = SampleLuminance(uv,  0, -1);
		l.w = SampleLuminance(uv, -1,  0);

#if (HIGH_Q)
        l.ne = SampleLuminance(uv,  1,  1);
		l.nw = SampleLuminance(uv, -1,  1);
		l.se = SampleLuminance(uv,  1, -1);
		l.sw = SampleLuminance(uv, -1, -1);
#endif

        l.highest = max(max(max(max(l.n, l.e), l.s), l.w), l.m);
		l.lowest = min(min(min(min(l.n, l.e), l.s), l.w), l.m);
		l.contrast = l.highest - l.lowest;

		return l;
    }

    bool ShouldSkipPixel(LuminanceData l)
    {
        float threshold = max(_ContrastThreshold, _RelativeThreshold * l.highest);
        return l.contrast < threshold;
    }

    float DeterminePixelBlendFactor (LuminanceData l)
    {
        float div = 8;
        float filter = 2 * (l.n + l.e + l.s + l.w);
#if (HIGH_Q)
        filter += l.ne + l.nw + l.se + l.sw;
        div += 4;
#endif
        filter /= div;
        filter = abs(filter - l.m);
        filter = saturate(filter / l.contrast);
        float blendFactor = smoothstep(0, 1, filter);
        return blendFactor * blendFactor;
    }

    EdgeData DetermineEdge (LuminanceData l)
    {
        EdgeData e;
        float horizontal = abs(l.n + l.s - 2 * l.m)
#if (HIGH_Q)
            * 2 + abs(l.ne + l.se - 2 * l.e) + abs(l.nw + l.sw - 2 * l.w)
#endif
        ;

        float vertical = abs(l.e + l.w - 2 * l.m)
#if (HIGH_Q)
            * 2 + abs(l.ne + l.nw - 2 * l.n) + abs(l.se + l.sw - 2 * l.s)
#endif
        ;
        e.isHorizontal = horizontal >= vertical;

        float pLuminance = e.isHorizontal ? l.n : l.e;
        float nLuminance = e.isHorizontal ? l.s : l.w;
        float pGradient = abs(pLuminance - l.m);
        float nGradient = abs(nLuminance - l.m);
        e.pixelStep = e.isHorizontal ? _MainTex_TexelSize.y : _MainTex_TexelSize.x;
        if (pGradient < nGradient)
        {
            e.pixelStep = -e.pixelStep;
        }
        return e;
    }

    half4 SharpenA(half2 uv, half4 color)
    {
        half2 p = _Params.zw;
        half2 p_h = p * 0.5;
        half4 blur = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + half2( p_h.x,   -p.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2( p_h.x,   -p.y), _MainTex_ST));
        blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + half2(  -p.x, -p_h.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2(  -p.x, -p_h.y), _MainTex_ST));
        blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + half2(   p.x,  p_h.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2(   p.x,  p_h.y), _MainTex_ST));
        blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + half2(-p_h.x,    p.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2(-p_h.x,    p.y), _MainTex_ST));
        blur *= 0.25;

        half4 lumaStrength = half4(0.222, 0.707, 0.071, 0.0) * _Params.x * 0.666;
        half4 sharp = color - blur;
        half4 sharpenColor = color + clamp(dot(sharp, lumaStrength), -_Params.y, _Params.y);
        return sharpenColor;
    }

    half4 SharpenB(half2 uv, half4 color)
    {
        half2 p = _Params.zw;
        half4 blur = SAMPLE_TEXTURE2D( _MainTex, sampler_MainTex, (uv + half2(-p.x, -p.y) * 1.5));
        blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2( p.x, -p.y) * 1.5));
        blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(-p.x,  p.y) * 1.5));
        blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2( p.x,  p.y) * 1.5));
        blur *= 0.25;

        return color + (color - blur) * _Params.x;
    }

    half4 Frag(VaryingsDefault i) : SV_Target
    {
        half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

        half2 p = _Params.zw;
        //half2 p_h = p * 0.5;
        //half4 blur = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + half2( p_h.x,   -p.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2( p_h.x,   -p.y), _MainTex_ST));
        //blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + half2(  -p.x, -p_h.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2(  -p.x, -p_h.y), _MainTex_ST));
        //blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + half2(   p.x,  p_h.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2(   p.x,  p_h.y), _MainTex_ST));
        //blur += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord + half2(-p_h.x,    p.y));//tex2D(_MainTex, StereoScreenSpaceUVAdjust(i.uv + half2(-p_h.x,    p.y), _MainTex_ST));
        //blur *= 0.25;

        //half4 lumaStrength = half4(0.222, 0.707, 0.071, 0.0) * _Params.x * 0.666;
        //half4 sharp = color - blur;

        half4 sharpenColor = SharpenA(i.texcoord, color);//color + clamp(dot(sharp, lumaStrength), -_Params.y, _Params.y);

#if (AA_ENABLE)
        half pixelBlend = 0;

        //luminance edge detect
        LuminanceData l = SampleLuminanceNeighborhood(i.texcoord);
        pixelBlend = DeterminePixelBlendFactor(l);
		EdgeData e = DetermineEdge(l);

        half4 orValue = GetPixelValue(i.texcoord);
        half4 sampledValue = 0;
        half4 blurColor = color;
#if (HIGH_Q)
        
        half2 offsets[8] = {
                    half2(-1, -1),
                    half2(-1, 0),
                    half2(-1, 1),
                    half2(0, -1),
                    half2(0, 1),
                    half2(1, -1),
                    half2(1, 0),
                    half2(1, 1)
                };

        for(int j = 0; j < 8; j++)
        {
            half2 uv = i.texcoord + offsets[j] * _MainTex_TexelSize * p;
            sampledValue += GetPixelValue(uv);

            if (e.isHorizontal)
            {
                uv.x += e.pixelStep * pixelBlend * p.x;
            }
            else
            {
                uv.y += e.pixelStep * pixelBlend * p.y;
            }
            blurColor += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
        }
        sampledValue *= 0.125;
        blurColor *= 1.0 / 9.0;
        blurColor += (sharpenColor + color) * 0.5;
        blurColor *= 0.5;
#elif (LOW_Q)
        
        half2 offsets[4] = {
                    half2(-1, 0),
                    half2(0, -1),
                    half2(0, 1),
                    half2(1, 0)
                };
        
        for(int j = 0; j < 4; j++)
        {
            half2 uv = i.texcoord + offsets[j] * _MainTex_TexelSize * p;
            sampledValue += GetPixelValue(uv);
        }
        sampledValue *= 0.25;

        half2 uv = i.texcoord;

        if (e.isHorizontal)
        {
            uv.x += e.pixelStep * pixelBlend * p.x;
        }
        else
        {
            uv.y += e.pixelStep * pixelBlend * p.y;
        }

        blurColor = color + SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
        blurColor *= 0.5;
#endif

        half edgeFactor = length(orValue - sampledValue);

        //half dd = orValue.w - sampledValue.w;//saturate(dot(orValue.w, sampledValue.w));
        half finalBlend = 0;
        if (ShouldSkipPixel(l))
        {
            finalBlend = edgeFactor;//dd * edgeFactor;
        }
        else
        {
            finalBlend = edgeFactor + l.contrast;
        }
        finalBlend = step(_Threshold, finalBlend);

        half4 finalColor = lerp(sharpenColor, lerp(0, blurColor, _Edge), finalBlend);
        //finalColor = lerp(finalColor, sharpenColor, step(_CompareSlider, i.texcoord.x));
#else
        half4 finalColor = sharpenColor;
#endif

//finalColor = 0;
//        finalColor.xy = _MainTex_TexelSize.xy;
        return saturate(finalColor);
    }

    ENDHLSL

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex VertDefault
            #pragma fragment Frag
            #pragma multi_compile _ AA_ENABLE
            #pragma multi_compile _ LOW_Q HIGH_Q
            ENDHLSL
        }
    }
}
