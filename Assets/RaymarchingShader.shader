Shader "Hidden/RaymarchingShader"
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

            sampler2D _MainTex;
            uniform float4x4 _CameraFrustum, _CamToWorld;

            uniform float _RM_MAX_DIST;
            uniform int _RM_MAX_STEPS;
            uniform float _RM_SURF_DIST;

            uniform float3 _LightPos;

            uniform float4 _Sphere1;

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

            float sdTorus(float3 fromPos)
            {
                //diameter, thickness
                float2 torusDimensions = float2(1.0f, 0.2f);

                float2 q = float2(length(fromPos.xz) - torusDimensions.x, fromPos.y);

                return length(q) - torusDimensions.y;
            }

            float sdSphere(float3 fromPos, float radius)
            {
                return length(fromPos)-radius;
            }

            float DistanceField(float3 fromPos)
            {
                float sphere1 = sdSphere(fromPos - float3(_Sphere1.xyz), _Sphere1.w);
                return sphere1;
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

            fixed4 Raymarch(float3 rayOrigin, float3 rayDir)
            {
                fixed4 result = fixed4(0, 0, 0, 0);

                float t = 0.0f;

                for (int iter = 0; iter < _RM_MAX_STEPS; ++iter)
                {

                    if (t > _RM_MAX_DIST)
                    {
                        //environment
                        result = fixed4(rayDir, 1.0f);
                        break;
                    }

                    float3 samplePos = rayOrigin + (rayDir*t);
                    float d = DistanceField(samplePos);
                    
                    if (d < _RM_SURF_DIST)
                    {
                        float3 normalAtPoint = GetNormalAt(samplePos);
                        float3 lightDir = (_LightPos- samplePos);
                        lightDir = normalize(lightDir);

                        float diffuseIntensity = dot(lightDir, normalAtPoint);

                        result = fixed4(diffuseIntensity, diffuseIntensity, diffuseIntensity, 1.0f);
                    }  

                    t += d;                
                }

                return result;
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
                float3 rayDir = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;

                fixed4 col = Raymarch(rayOrigin, rayDir);
                return col;
            }
            ENDCG
        }
    }
}
