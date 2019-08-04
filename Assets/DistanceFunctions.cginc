// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

// Box
// b: size of box in x/y/z
float sdBox(float3 p, float3 b)
{
	float3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) +
		length(max(d, 0.0));
}

//Round box
float sdRoundBox( float3 p, float3 b, float r )
{
  float3 d = abs(p) - b;
  return length(max(d,0.0)) - r
         + min(max(d.x,max(d.y,d.z)),0.0); // remove this line for an only partially signed sdf 
}

//Torus
//t (torus)
float sdTorus(float3 p, float2 t)
{
	float2 q = float2(length(p.xz) - t.x, p.y);

    return length(q) - t.y;
}

//Plane
float sdPlane( float3 p, float4 n )
{
  // n must be normalized
  return dot(p,n.xyz) + n.w;
}

// BOOLEAN OPERATORS //

// Union
float opU(float d1, float d2)
{
	return min(d1, d2);
}
//Smooth union
float opUS(float d1, float d2, float k)
{
	float h = clamp(0.5 + 0.5*(d1 - d2)/k, 0.0, 1.0);
	return lerp(d1, d2, h) - k*h*(1.0 - h);
}

// Subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
	return max(d1, d2);
}

//elongates the shape
//returns the distance offset
float4 opElongate(float3 p, float3 h)
{	
	float3 q = abs(p) - h;
	float4 w = float4( max(q, 0.0f), min( max( q.x, max(q.y, q.z) ), 0.0f ) );
	return w;
}

float3 opTwistY(float3 p, float k)
{
    float c = cos(k*p.y);
	float s = sin(k*p.y);

	float2x2 m = float2x2(c, s, -s, c);
	float2 pXZ = m*float2x1(p.xz);
	//return float3(pXZ, p.y);
	return float3(pXZ.x, p.y, pXZ.y);
}

float3 opRotateY(float3 p, float degree)
{
	float theta = degree*0.0174533f;
	float cosTheta = cos(theta);
	float sinTheta = sin(theta);

	return float3(cosTheta*p.x - sinTheta*p.z,p.y, sinTheta*p.x + cosTheta*p.z);
}

// Mod Position Axis
//basically opRepeat
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}