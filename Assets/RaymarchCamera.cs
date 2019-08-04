using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : SceneViewFilter
{
	[SerializeField]
    private Shader _Shader;

    [Min(0)]
    public float _RM_MaxDist;
    [Min(0)]
    public int _RM_MaxSteps;
    [Min(0)]
    public float _RM_SurfaceDistance;
    [Min(0)]
    public float _SmoothingFactor;

    public Vector4 _Sphere1;
    public Vector4 _Cube1;
    public float _Cube1RoundingRadius;
    public Vector4 _GroundPlane;
    public float _RotationDegree;
    [Min(0)]
    public int _NumRotatedCopies;

    public Color _MainColor;

    [Header("Light & Shadow")]
    public Transform _LightTransform;
    public Color _LightColor;
    [Range(0,1)]
    public float _LightAmbientIntensity;
    [Range(0,2)]
    public float _AOStepSize;
    [Range(0,3)]
    public int _AOMaxIterations;
    [Range(0,1)]
    public float _AOIntensity;
    public Vector2 _ShadowDist;
    [Range(0,5)]
    public float _ShadowIntensity;
    [Range(0,24)]
    public float _PenumbraFactor;

    [Header("Reflection")]
    public Cubemap _EnvReflectionCubemap;
    [Range(0,3)]
    public int _ReflectionCount;
    [Range(0,1)]
    public float _ReflectionIntensity;
    [Range(0,1)]
    public float _EnvReflectionIntensity;

    [Header("Effects")]
    public Vector4 _SpaceFoldingSettings;
    public Vector4 _GlowSettings;

    public Material _RaymarchMaterial
    {
    	get
    	{
    		if (!_RaymarchMaterialIntl && _Shader)
    		{
    			_RaymarchMaterialIntl = new Material(_Shader);
    			_RaymarchMaterialIntl.hideFlags = HideFlags.HideAndDontSave;
    		}
    		return _RaymarchMaterialIntl;
    	}
    }
    private Material _RaymarchMaterialIntl;

    public Camera _Camera
    {
    	get
    	{
    		if (!_CameraIntl)
    		{
    			_CameraIntl = GetComponent<Camera>();
    		}

    		return _CameraIntl;
    	}
    }
    private Camera _CameraIntl;

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
    	if (!_RaymarchMaterial)
    	{
    		Graphics.Blit(source, destination);
    		return;
    	}

    	//Camera
    	_RaymarchMaterial.SetMatrix("_CameraFrustum", GetCameraFrustums(_Camera));
    	_RaymarchMaterial.SetMatrix("_CamToWorld", _Camera.cameraToWorldMatrix);

    	//RayMarching Variables
    	_RaymarchMaterial.SetFloat("_RM_MAX_DIST", _RM_MaxDist);
    	_RaymarchMaterial.SetInt("_RM_MAX_STEPS", _RM_MaxSteps);
    	_RaymarchMaterial.SetFloat("_RM_SURF_DIST", _RM_SurfaceDistance);
        _RaymarchMaterial.SetFloat("_SmoothingFactor", _SmoothingFactor);

    	//Light
    	_RaymarchMaterial.SetVector("_LightPos", _LightTransform.position);
    	_RaymarchMaterial.SetFloat("_LightAmbientIntensity", _LightAmbientIntensity);
        _RaymarchMaterial.SetColor("_LightColor", _LightColor);

        _RaymarchMaterial.SetFloat("_AOStepSize", _AOStepSize);
        _RaymarchMaterial.SetFloat("_AOIntensity", _AOIntensity);
        _RaymarchMaterial.SetInt("_AOMaxIterations", _AOMaxIterations);

    	_RaymarchMaterial.SetColor("_MainColor", _MainColor);

    	_RaymarchMaterial.SetFloat("_ShadowIntensity", _ShadowIntensity);
    	_RaymarchMaterial.SetVector("_ShadowDist", _ShadowDist);
        _RaymarchMaterial.SetFloat("_PenumbraFactor", _PenumbraFactor);

        //Reflection
        _RaymarchMaterial.SetFloat("_ReflectionIntensity", _ReflectionIntensity);
        _RaymarchMaterial.SetInt("_ReflectionCount", _ReflectionCount);
        _RaymarchMaterial.SetTexture("_EnvReflectionCubemap", _EnvReflectionCubemap);
        _RaymarchMaterial.SetFloat("_EnvReflectionIntensity", _EnvReflectionIntensity);

        //Effects
        _RaymarchMaterial.SetVector("_SpaceFoldingSettings", _SpaceFoldingSettings);
        _RaymarchMaterial.SetVector("_GlowSettings", _GlowSettings);

    	//Scene
    	_RaymarchMaterial.SetVector("_Sphere1", _Sphere1);
    	_RaymarchMaterial.SetVector("_Cube1", _Cube1);
        _RaymarchMaterial.SetFloat("_Cube1RoundingRadius", _Cube1RoundingRadius);
    	_RaymarchMaterial.SetVector("_Ground", _GroundPlane);
        _RaymarchMaterial.SetFloat("_RotationDegree", _RotationDegree);
        _RaymarchMaterial.SetInt("_NumRotatedCopies", _NumRotatedCopies);

    	RenderTexture.active = destination;
        _RaymarchMaterial.SetTexture("_MainTex", source);

    	GL.PushMatrix();
    	GL.LoadOrtho();

    	_RaymarchMaterial.SetPass(0);

    	GL.Begin(GL.QUADS);

    	//BL
    	GL.MultiTexCoord2(0, 0.0f, 0.0f);
    	GL.Vertex3(0.0f, 0.0f, 3.0f);

    	//BR
    	GL.MultiTexCoord2(0, 1.0f, 0.0f);
    	GL.Vertex3(1.0f, 0.0f, 2.0f);

    	//TR
    	GL.MultiTexCoord2(0, 1.0f, 1.0f);
    	GL.Vertex3(1.0f, 1.0f, 1.0f);

    	//TL
    	GL.MultiTexCoord2(0, 0.0f, 1.0f);
    	GL.Vertex3(0.0f, 1.0f, 0.0f);

    	GL.End();
    	GL.PopMatrix();
    }

    private Matrix4x4 GetCameraFrustums(Camera cam)
    {
    	Matrix4x4 frustums = Matrix4x4.identity;

    	float fov = Mathf.Tan((cam.fieldOfView*0.5f)*Mathf.Deg2Rad);

    	Vector3 goUp = Vector3.up * fov;
    	Vector3 goRight = Vector3.right * fov * cam.aspect;

    	Vector3 topLeft = (-Vector3.forward - goRight + goUp);
    	Vector3 topRight = (-Vector3.forward + goRight + goUp);
    	Vector3 bottomRight = (-Vector3.forward + goRight - goUp);
    	Vector3 bottomLeft = (-Vector3.forward - goRight - goUp);

    	frustums.SetRow(0, topLeft);
    	frustums.SetRow(1, topRight);
    	frustums.SetRow(2, bottomRight);
    	frustums.SetRow(3, bottomLeft);

    	return frustums;
    }
}
