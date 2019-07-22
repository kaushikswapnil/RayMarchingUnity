using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RaymarchCamera : SceneViewFilter
{
	[SerializeField]
    private Shader _Shader;

    public float _RM_MaxDist;
    public int _RM_MaxSteps;
    public float _RM_SurfaceDistance;

    public Vector4 _Sphere1;

    public Vector3 _LightPos;

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

    [ImageEffectOpaque]
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

    	//Light
    	_RaymarchMaterial.SetVector("_LightPos", _LightPos);

    	//Scene
    	_RaymarchMaterial.SetVector("_Sphere1", _Sphere1);

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
