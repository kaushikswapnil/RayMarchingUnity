// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

shader "Swapnil/RaymarchingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "DistanceFunctions.cginc"

            uniform sampler2D _MainTex;
            uniform float4x4 _CameraFrustum, _CamToWorld;

            uniform float _RM_MAX_DIST;
            uniform int _RM_MAX_STEPS;
            uniform float _RM_SURF_DIST;
            uniform float _SmoothingFactor;

            uniform float2 _ShadowDist;
            uniform float _ShadowIntensity;
            uniform float _PenumbraFactor;

            uniform float3 _LightPos;
            uniform fixed4 _LightColor;
            uniform float _LightAmbientIntensity;
            uniform float _AOStepSize;
            uniform int _AOMaxIterations;
            uniform float _AOIntensity;

            uniform samplerCUBE _EnvReflectionCubemap;
            uniform float _EnvReflectionIntensity;
            uniform float _ReflectionIntensity;
            uniform int _ReflectionCount;

            uniform float4 _SpaceFoldingSettings;
            uniform float4 _GlowSettings;
            uniform float4 _SubjectElongationSettings;
            uniform float4 _SubjectTwistingSettings;

            uniform fixed4 _MainColor;

            uniform float4 _Sphere1;
            uniform float4 _Cube1;
            uniform float _Cube1RoundingRadius;
            uniform float _RotationDegree;
            uniform int _NumRotatedCopies;

            uniform fixed4 _Ground;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            float DF_Ground(float3 fromPos)
            {
                return sdPlane(fromPos, float4(_Ground.xyzw));
            }

            float DF_Subject(float3 fromPos)
            {
            	//w is used for elongation offset
            	float4 pSphere1 = float4(fromPos - float3(_Sphere1.xyz), 0.0f);;
                float4 pCube1 = float4(fromPos - float3(_Cube1.xyz), 0.0f);

                if (_SubjectElongationSettings.w > 0.0f)
                {
                	pSphere1 = opElongate(pSphere1.xyz, _SubjectElongationSettings.xyz);
                	pCube1 = opElongate(pCube1.xyz, _SubjectElongationSettings.xyz);
                }

                if (_SubjectTwistingSettings.w > 0.0f)
                {
                	pSphere1 = float4(opTwistY(pSphere1.xyz, _SubjectTwistingSettings.y), pSphere1.w);
                	pCube1 = float4(opTwistY(pCube1.xyz, _SubjectTwistingSettings.y), pCube1.w);
                }

                float sphere1 = pSphere1.w + sdSphere(pSphere1.xyz, _Sphere1.w);
                float cube1 = pCube1.w + sdRoundBox( pCube1.xyz, float3(_Cube1.www), _Cube1RoundingRadius);
                //float cube1 = sdBox(fromPos - float3(_Cube1.xyz), float3(_Cube1.www));

                return opS(sphere1, cube1);
                //return opUS(sphere1, cube1, _SmoothingFactor);
            }

            float DistanceField(float3 fromPos)
            {
            	float3 p = fromPos;

            	//Space folding is enabled
            	if (_SpaceFoldingSettings.w > 0.f)
            	{
            		pMod1(p.x, _SpaceFoldingSettings.x);
	                pMod1(p.y, _SpaceFoldingSettings.y);
	                pMod1(p.z, _SpaceFoldingSettings.z);
	                float dfSub = DF_Subject(p);

	                for (int iter = 1; iter <= _NumRotatedCopies; ++iter)
	                {
	                	dfSub = opU(dfSub, DF_Subject(opRotateY(p, _RotationDegree*iter)));
	                }
	                
	                return dfSub;
            	}

            	//Perform ground df before subject operations
                float dfGround = DF_Ground(p);
                float dfSub = DF_Subject(p);

                for (int iter = 1; iter <= _NumRotatedCopies; ++iter)
                {
                	dfSub = opU(dfSub, DF_Subject(opRotateY(p, _RotationDegree*iter)));
                }

                return opU(dfSub, dfGround);
            }

            float CalculateAmbientOcclusionAt(float3 p, float n)
            {
                float step = _AOStepSize;
                float ao = 0.0f;
                float dist;

                for (int iter = 1; iter <= _AOMaxIterations; ++iter)
                {
                    dist = step*iter;
                    ao += max(0.0f, (dist - DF_Subject(p + (n*dist)))/dist);
                }

                return 1 - (ao*_AOIntensity);
            }

            float CalculateHardShadowInvAt(float3 p, float3 rd, float tMin, float tMax)
            {
            	//Check if point is in shadow
                float t = tMin;
                float3 ro = p;

                float shadowIntensity = 1.f;

                while (t < tMax)
                {
                    float d = DF_Subject(ro + (rd*t)); //Should be distance field but we dont want ground to have a shadow
                    if (d < 0.001)
                    {
                        shadowIntensity = 0.0f;
                        break;
                    }

                    t += d;
                }

                return shadowIntensity;
            }

            float CalculateSoftShadowInvAt(float3 ro, float3 rd, float tMin, float tMax, float k)
            {
            	//Check if point is in shadow
                float t = tMin;
                float shadowIntensity = 1.f;

                while (t < tMax)
                {
                    float d = DF_Subject(ro + (rd*t));
                    if (d < 0.001)
                    {
                        shadowIntensity = 0.0f;
                        break;
                    }

			        shadowIntensity = min( shadowIntensity, k*d/t );

                    t += d;
                }

                return shadowIntensity;
            }

            float3 GetLightIntensityAt(float3 fromPos, float3 normalAtPoint)
            {
                float3 dispToLight = _LightPos- fromPos;
                float3 lightDir = normalize(dispToLight);

                float diffuseIntensity = (dot(lightDir, normalAtPoint)*0.5) + 0.5;
                float shadowIntensity = CalculateSoftShadowInvAt(fromPos, lightDir, _ShadowDist.x, _ShadowDist.y, _PenumbraFactor);

                //float shadowIntensity = CalculateHardShadowInvAt(fromPos, lightDir, _ShadowDist.x, _ShadowDist.y);

                shadowIntensity = shadowIntensity*0.5 + 0.5;

                shadowIntensity = max(0.0f, pow(shadowIntensity, _ShadowIntensity));

                float ambientOcclusion = CalculateAmbientOcclusionAt(fromPos, normalAtPoint);

                float totalLightIntensity = diffuseIntensity + _LightAmbientIntensity;

                totalLightIntensity *= shadowIntensity;
                totalLightIntensity *= ambientOcclusion;

                return _LightColor.rgb * totalLightIntensity;
            }

            float3 CalculateShading(float3 p, float3 n)
            {
            	float3 lightIntensity = GetLightIntensityAt(p, n);
            	float3 mainCol = _MainColor.xyz;

            	return mainCol*lightIntensity;
            }

            float3 GetNormalAt(float3 p)
            {
                float2 epsilon = float2(0.01f, 0.0f);

                float3 normal = float3(
                    (DistanceField(p + epsilon.xyy) - DistanceField(p - epsilon.xyy)),
                    (DistanceField(p + epsilon.yxy) - DistanceField(p - epsilon.yxy)),
                    (DistanceField(p + epsilon.yyx) - DistanceField(p - epsilon.yyx)));


                return normalize(normal);
            }

            bool Raymarch(float3 rayOrigin, float3 rayDir, inout float3 collisionPoint, inout float collisionDist, inout int numSteps, inout float recordDistance, int rm_maxIterations, float rm_maxDistance)
            {
                float t = 0.01f;
                recordDistance = rm_maxDistance;

                for (int iter = 0; iter < rm_maxIterations; ++iter)
                {

                    if (t > rm_maxDistance)
                    {
                        //environment
                        break;
                    }

                    float3 samplePos = rayOrigin + (rayDir*t);
                    float d = DistanceField(samplePos);
                    recordDistance = min(recordDistance, d);
                    
                    if (d < _RM_SURF_DIST)
                    {
                        collisionPoint = samplePos;
                        collisionDist = t;
                        numSteps = iter + 1;
                        return true;
                        break;
                    }  

                    t += d;                
                }

                return false;
            }

            v2f vert (appdata v)
            {
                v2f o;

                half index = v.vertex.z;
                v.vertex.z = 0;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = _CameraFrustum[(int)index].xyz;
                o.ray /= abs(o.ray.z);

                o.ray = mul(_CamToWorld, o.ray);

                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 colTex = tex2D(_MainTex, i.uv);
                float3 rayDir = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;

                fixed4 result = fixed4(0, 0, 0, 0);

                float collisionDist;
                float3 collisionPoint;
                float recordDistance;
                int numSteps;
                if (Raymarch(rayOrigin, rayDir, collisionPoint, collisionDist, numSteps, recordDistance, _RM_MAX_STEPS, _RM_MAX_DIST)) //We have collided
                {
                	fixed3 normalAtCollisionPoint = GetNormalAt(collisionPoint);
                    fixed3 colAtPoint = CalculateShading(collisionPoint, normalAtCollisionPoint);
                    result = fixed4(colAtPoint, 1.0f);

                    if (_GlowSettings.w > 0.0f)
                    {
                    	float glowIntensity = 0.5f;
                        if (collisionDist > _GlowSettings.w)
                        {
                            glowIntensity *= _GlowSettings.w/collisionDist;
                        }

                		//float glowIntensity = recordDistance/_GlowSettings.w;
                		result += fixed4(_GlowSettings.xyz*glowIntensity, 0.0f);
                    }

                    bool reflectEnv = (_ReflectionCount > 0);

                    for (int refIter = 0; refIter < _ReflectionCount; ++refIter)
                    {
                    	rayDir = normalize(reflect(rayDir, normalAtCollisionPoint));
                    	rayOrigin = collisionPoint + (rayDir*0.01f);
                    	
                    	if (Raymarch(rayOrigin, rayDir, collisionPoint, collisionDist, numSteps, recordDistance,_RM_MAX_STEPS*0.5f, _RM_MAX_DIST/2))
                    	{
                    		normalAtCollisionPoint = GetNormalAt(collisionPoint);
                    		colAtPoint = CalculateShading(collisionPoint, normalAtCollisionPoint);

                    		result += fixed4(colAtPoint*_ReflectionIntensity*0.5, 0);

                    		if (reflectEnv == true)
                    		{
                    			reflectEnv = false;
                    		}
                    	}
                    }

                    //Env reflection
                    if (reflectEnv)
                    {
                    	result += fixed4(texCUBE(_EnvReflectionCubemap, normalAtCollisionPoint).rgb * _EnvReflectionIntensity * _ReflectionIntensity, 0.0f);
                    }                    
                }
                else if (_GlowSettings.w > 0.f && recordDistance < _GlowSettings.w)
                {
                	recordDistance = _GlowSettings.w - recordDistance;
                	float glowIntensity = recordDistance/_GlowSettings.w;
                	result = fixed4(_GlowSettings.xyz*glowIntensity, glowIntensity);
                }

                fixed4 col = fixed4((colTex * (1.0 - result.w)) + (result.xyz * result.w), 1.0f);
                return col;
            }
            ENDCG
        }
    }
}
