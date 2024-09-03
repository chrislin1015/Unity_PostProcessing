using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

public enum RunType
{
    RealTime,
    Editor
}

[Serializable]
public sealed class RunTypeParameter : ParameterOverride<RunType> { }

[Serializable]
[PostProcess(typeof(AreaLightPpRenderer), PostProcessEvent.BeforeTransparent, "LINK/AreaLight")]
public class AreaLightPp : PostProcessEffectSettings
{
    [Range(0.0f, 1.0f), Tooltip("Strength")]
    public FloatParameter strength = new FloatParameter { value = 0.5f };

    [DisplayName("Run Type")]
    public RunTypeParameter runTypeParameter = new RunTypeParameter { value = RunType.Editor };
}

public sealed class AreaLightPpRenderer : PostProcessEffectRenderer<AreaLightPp>
{
    const int LIGHTCOUNT = 16;

    Shader _shader = Shader.Find("LINK/Post-Process/AreaLight");

    int _lightCount = 0;
    Vector4[] _lightPos = new Vector4[LIGHTCOUNT];

    Vector4[] _lightDir = new Vector4[LIGHTCOUNT];

    //light.range, light.areaSize.x, light.areaSize.y, light.bounceIntensity
    Vector4[] _lightParameter = new Vector4[LIGHTCOUNT];

    //light.color.r, light.color.g, light.color.b, light.intensity
    Vector4[] _lightColor = new Vector4[LIGHTCOUNT];
    Matrix4x4[] _lightInverseMatrix = new Matrix4x4[LIGHTCOUNT];

    public override void Init()
    {

    }

    public override DepthTextureMode GetCameraFlags()
    {
        return DepthTextureMode.DepthNormals | DepthTextureMode.Depth;
    }

    public override void Render(PostProcessRenderContext context)
    {
        if (_shader == null || context == null)
            return;

        PropertySheet propertySheet = context.propertySheets.Get(_shader);
        if (propertySheet == null)
            return;

        RefreshLightData();

        propertySheet.ClearKeywords();
        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false);
        propertySheet.properties.SetMatrix(Shader.PropertyToID("_InverseProjectionMatrix"), projectionMatrix.inverse);
        propertySheet.properties.SetMatrix(Shader.PropertyToID("_InverseViewMatrix"),
            context.camera
                .cameraToWorldMatrix); //.worldToCameraMatrix.inverse);//ShaderIDs.InverseViewMatrix, context.camera.worldToCameraMatrix.inverse);
        propertySheet.properties.SetMatrix(Shader.PropertyToID("_ViewProjectInverse"),
            Matrix4x4.Inverse(projectionMatrix * context.camera.worldToCameraMatrix));

        propertySheet.properties.SetInt("_LightCount", _lightCount);
        propertySheet.properties.SetFloat("_Strength", settings.strength.value);
        propertySheet.properties.SetVectorArray("_LightPosition", _lightPos);
        propertySheet.properties.SetVectorArray("_LightDir", _lightDir);
        propertySheet.properties.SetVectorArray("_LightParameter", _lightParameter);
        propertySheet.properties.SetVectorArray("_LightColor", _lightColor);
        propertySheet.properties.SetMatrixArray("_LightInverseMatrix", _lightInverseMatrix);
#if UNITY_EDITOR
        if (Application.isPlaying)
        {
            if (settings.runTypeParameter.value == RunType.RealTime)
                propertySheet.EnableKeyword("REALTIMEL_LIGHT");
            else
                propertySheet.DisableKeyword("REALTIMEL_LIGHT");
        }
        else
            propertySheet.DisableKeyword("REALTIMEL_LIGHT");
#else
            if (settings.runTypeParameter.value == RunType.RealTime)
                propertySheet.EnableKeyword("REALTIMEL_LIGHT");
            else
                propertySheet.DisableKeyword("REALTIMEL_LIGHT");
#endif
        context.command.BlitFullscreenTriangle(context.source, context.destination, propertySheet, 0);
    }

    void ClearNoUseAreaLight()
    {
        AreaLightFaker.RefreshAreaLight();
    }

    int GetLightType(Light light)
    {
        return (int)light.type;
    }

    void RefreshLightData()
    {
        if (!Application.isPlaying)
            ClearNoUseAreaLight();

        _lightCount = 0;

        if (AreaLightFaker.areaLights == null || AreaLightFaker.areaLights.Count == 0)
            return;

        if (AreaLightFaker.areaLightFakers == null || AreaLightFaker.areaLightFakers.Count == 0)
            return;

        for (int i = 0; i < AreaLightFaker.areaLightFakers.Count; ++i)
        {
            if (i >= LIGHTCOUNT)
                break;

            AreaLightFaker areaLightFaker = AreaLightFaker.areaLightFakers[i]; //light.GetComponent<AreaLightFaker>();
            if (areaLightFaker == null)
                continue;

            if (!areaLightFaker.IsEnable())
                continue;

            //加上aabb test
            if (!areaLightFaker.BoundingTest())
                continue;

            Light light = AreaLightFaker.areaLightFakers[i].myLight;

            _lightPos[_lightCount] = light.transform.position;
            _lightPos[_lightCount].w = GetLightType(light);
            _lightDir[_lightCount] = light.transform.forward;
#if UNITY_EDITOR
            _lightParameter[_lightCount] =
                new Vector4(light.range, light.areaSize.x, light.areaSize.y, light.bounceIntensity);
#else
                _lightParameter[_lightCount] =
 new Vector4(light.range, areaLightFaker.areaSize.x, areaLightFaker.areaSize.y, light.bounceIntensity);
#endif
            _lightColor[_lightCount] = new Vector4(light.color.r, light.color.g, light.color.b, light.intensity);
            _lightInverseMatrix[_lightCount] = light.transform.worldToLocalMatrix;
            _lightCount++;
        }
    }
}
