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

            uniform float2 _ShadowDist;
            uniform float _ShadowIntensity;
            uniform float _PenumbraFactor;

            uniform float3 _LightPos;
            uniform fixed4 _LightColor;
            uniform float _LightAmbientIntensity;
            uniform float _AOStepSize;
            uniform int _AOMaxIterations;
            uniform float _AOIntensity;

            uniform fixed4 _MainColor;

            uniform float4 _Sphere1;
            uniform float4 _Cube1;
            uniform float _Cube1RoundingRadius;

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
                float sphere1 = sdSphere(fromPos - float3(_Sphere1.xyz), _Sphere1.w);
                float cube1 = sdRoundBox(fromPos - float3(_Cube1.xyz), float3(_Cube1.www), _Cube1RoundingRadius);
                //float cube1 = sdBox(fromPos - float3(_Cube1.xyz), float3(_Cube1.www));


                return opS(sphere1, cube1);
            }

            float DistanceField(float3 fromPos)
            {
                //float3 fromPos = float3(fromPos1.xyz);
                //pMod1(fromPos.x, 4);
                //pMod1(fromPos.y, 4);
                //pMod1(fromPos.z, 4);
                return opU(DF_Subject(fromPos), DF_Ground(fromPos));
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

            bool Raymarch(float3 rayOrigin, float3 rayDir, inout float3 collisionPoint, inout float collisionDist, inout int numSteps)
            {
                float t = 0.01f;

                for (int iter = 0; iter < _RM_MAX_STEPS; ++iter)
                {

                    if (t > _RM_MAX_DIST)
                    {
                        //environment
                        break;
                    }

                    float3 samplePos = rayOrigin + (rayDir*t);
                    float d = DistanceField(samplePos);
                    
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
                int numSteps;
                if (Raymarch(rayOrigin, rayDir, collisionPoint, collisionDist, numSteps)) //We have collided
                {
                    fixed3 colAtPoint = CalculateShading(collisionPoint, GetNormalAt(collisionPoint));
                    result = fixed4(colAtPoint, 1.0f);
                }

                fixed4 col = fixed4((colTex * (1.0 - result.w)) + (result.xyz * result.w), 1.0f);
                return col;
            }
            ENDCG
        }
    }
}
