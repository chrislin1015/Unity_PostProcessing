using System.Collections.Generic;
using Unity.Collections;
using UnityEngine;

[ExecuteInEditMode]
public class AreaLightFaker : MonoBehaviour
{

    static List<Light> _areaLights = new List<Light>();
    static List<AreaLightFaker> _areaLightFakers = new List<AreaLightFaker>();

    static public List<Light> areaLights
    {
        get { return _areaLights; }
    }

    static public List<AreaLightFaker> areaLightFakers
    {
        get { return _areaLightFakers; }
    }

    Light _light;

    public Light myLight
    {
        get { return _light; }
    }

    public bool isRealTime;
    //public LightType lightType;

    [ReadOnly] public Vector2 areaSize;

    static Camera _camera;
    Bounds _bounds;

    static void Rebuild()
    {
        if (_areaLights == null)
            _areaLights = new List<Light>();

        if (_areaLightFakers == null)
            _areaLightFakers = new List<AreaLightFaker>();

        _areaLights.Clear();
        _areaLightFakers.Clear();

        AreaLightFaker[] lights = GameObject.FindObjectsOfType<AreaLightFaker>();
        if (lights == null || lights.Length == 0)
            return;

        for (int i = 0; i < lights.Length; ++i)
        {
            lights[i].Reset();
        }
    }

    static public void RefreshAreaLight()
    {
        Rebuild();
    }

    void Awake()
    {
        if (_camera == null)
            _camera = Camera.main;

        Reset();
    }

    void OnDestroy()
    {
        _light = null;
    }

    // Update is called once per frame
    void Update()
    {
#if UNITY_EDITOR
        if (_light == null)
        {
            Reset();
        }
        else
        {
            areaSize = _light.areaSize;
        }
#endif
    }

    public void Reset()
    {
        _light = GetComponent<Light>();
        if (_light.type == LightType.Point ||
            _light.type == LightType.Area ||
            _light.type == LightType.Rectangle ||
            _light.type == LightType.Disc)
        {
            if (!_areaLights.Contains(_light))
                _areaLights.Add(_light);

            if (!_areaLightFakers.Contains(this))
                _areaLightFakers.Add(this);
#if UNITY_EDITOR
            areaSize = _light.areaSize;
#endif
        }

        LightBounding();
    }

    public void LightBounding()
    {
        if (_light == null)
            return;

        if (_light.type == LightType.Point)
        {
            _bounds = new Bounds(_light.transform.position, new Vector3(_light.range, _light.range, _light.range));
        }
        else if (_light.type == LightType.Rectangle)
        {
            _bounds = new Bounds(_light.transform.position,
                new Vector3(_light.range * 2, _light.range * 2, _light.range * 2));
        }
        else if (_light.type == LightType.Disc)
        {
            _bounds = new Bounds(_light.transform.position,
                new Vector3(_light.range * 2, _light.range * 2, _light.range * 2));
        }
    }

    public bool IsEnable()
    {
        if (_light == null)
            return false;

        if (_light.intensity <= 0.0f)
            return false;

        if (isRealTime && Application.isPlaying && enabled)
        {
            return true;
        }
        else if (!isRealTime && !Application.isPlaying && _light.enabled && enabled)
        {
            return true;
        }

        return false;
    }

    public bool BoundingTest()
    {
        if (_light == null)
            return false;

        if (!Application.isPlaying && !isRealTime)
            return true;

        LightBounding();
        return CalculateStatistics(_camera, _bounds);
    }

    static public bool CalculateStatistics(Camera camera, Bounds bounds)
    {
        Plane[] planes = GeometryUtility.CalculateFrustumPlanes(camera);
        return IsVisible(bounds, planes);
    }

    static bool IsVisible(Bounds bounds, Plane[] planes)
    {
        return GeometryUtility.TestPlanesAABB(planes, bounds);
    }
}