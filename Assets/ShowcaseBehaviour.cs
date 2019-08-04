using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu()]
public class ShowcaseBehaviour : ScriptableObject
{
    RaymarchCamera _RaymarchCamera;

    public Color _LightColor;
    public Color _MainColor;

    public ShowcaseBehaviour(RaymarchCamera rayCam)
    {
    	_RaymarchCamera = rayCam;
    }

    public void OnStart()
    {
    	//Setting up and giving initial values to

    	//ray march shader
    	_RaymarchCamera._RM_SurfaceDistance = 0.001f;
    	_RaymarchCamera._RM_MaxDist = 1000.0f;
    	_RaymarchCamera._RM_MaxSteps = 500;

    	_RaymarchCamera._LightColor = _LightColor;
    	_RaymarchCamera._MainColor = _MainColor;

    	//light & shadow

    	//effects

    	//scene
    }

    public void Update()
    {

    }
}
