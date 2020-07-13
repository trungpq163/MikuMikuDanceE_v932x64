float InnerSize <
   string UIName = "InnerSize";
   string UIWidget = "Slider";
   string UIHelp = "内側大きさ";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 2;
> = 2.0;
float OuterSize <
   string UIName = "OuterSize";
   string UIWidget = "Slider";
   string UIHelp = "幅";
   bool UIVisible =  true;
   float UIMin = 0;
   float UIMax = 10;
> = 2.0;



////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse        : WORLDVIEWINVERSE;
float4x4 WorldMatrix      : WORLD;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

//コントロール用値取得
float Tr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float Si  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float time : Time;

texture BodyTex<
    string ResourceName = "Body.png";
>;
sampler Body = sampler_state {
    texture = <BodyTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

#ifndef MIKUMIKUMOVING

texture BodyTex_thunder : ANIMATEDTEXTURE <
    string ResourceName = "Body_thunder.png";
    string SeekVariable="time";
>;
sampler Body_thunder = sampler_state {
    texture = <BodyTex_thunder>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV  = WRAP;
};

#endif
texture BodyTex_red<
    string ResourceName = "Body_red.png";
>;
sampler Body_red = sampler_state {
    texture = <BodyTex_red>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = WRAP;
    AddressV  = WRAP;
};
texture HeadTex<
    string ResourceName = "Head.png";
>;
sampler Head = sampler_state {
    texture = <HeadTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
texture HeadTex_red<
    string ResourceName = "Head_red.png";
>;
sampler Head_red = sampler_state {
    texture = <HeadTex_red>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};
static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};
///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float alpha		  : TEXCOORD1;	//α
};

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0,uniform int mode)
{
	float3 Eye = CameraPosition - mul( float4(0,0,0,1), WorldMatrix );
	float3 Vec = WorldMatrix[2].xyz;
	
	float d = abs(dot(normalize(Eye),normalize(Vec)));
	Tr *= OuterSize;
    VS_OUTPUT Out;
    Out.alpha = 1.0;
    if(mode == 1 || mode == 3)
    {
	    //回転
	    Pos.xyz = Pos.yxz;
	    Tex.y += 0.5;
	}
	if(mode == 2 || mode == 5)
	{
		float rot_z = time*2;
		
		float3x3 RotationZ = {
		    {cos(rot_z), sin(rot_z), 0},
		    {-sin(rot_z), cos(rot_z), 0},
		    {0, 0, 1},
		};
		Pos.xyz = mul(Pos.zxy,RotationZ);
		//Pos.xyz = Pos.zxy;
		// ビルボード
		//Pos.xyz = mul( Pos.xyz, BillboardMatrix );
		//太さ
		Pos.xyz *= Tr*0.5*1.5;
		
		if(mode == 5)
		{
		    Pos.xyz *= InnerSize;
		}
	    Out.alpha = pow(d,128);
		Pos.z += min(5,length(Eye)/Si-0.5);
		
	}else{
		Pos.xy *= lerp(1,1-pow(abs(Pos.z*0.5+0.5),8),1-d);
		Pos.xy *= saturate(abs(Pos.z*0.5+0.5)*8);
		Out.alpha = lerp(0,1-pow(abs(Pos.z*0.5+0.5),8),1-pow(d,128));
		Pos.z += 1.0;
		Pos.z *= 2.5;
		//太さ
		Pos.xy *= Tr;
		if(mode == 3)
		{
		    Pos.xy *= InnerSize;
		}
	}
	Out.alpha = saturate(Out.alpha);
	
	
	// カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( float2 Tex :TEXCOORD0,float alpha :TEXCOORD1 ,uniform int mode) : COLOR0
{
	if(mode == 0)
	{
		float4 col;// = tex2D( Body, Tex + float2(0,time*1) );
		col = 0;
		col.a = 1;
		#ifndef MIKUMIKUMOVING
		col.rgb += tex2D( Body_thunder, Tex*0.25 + float2(0,time*0) ).rgb;
		col.rgb += tex2D( Body_thunder, Tex*0.25 + float2(0,time*0) + float2(0,0.5) ).rgb;
		#endif
	    return col * float4(1,1,1,alpha);
	}else if(mode == 1)
	{
		Tex.y += time*1;
	    return tex2D( Body_red, Tex ) * float4(1,1,1,alpha);
	    //return tex2D( Head, Tex );
	}else if(mode == 2)
	{
	    return tex2D( Head, Tex ) * float4(1,1,1,alpha);
	}else if(mode == 3)
	{
	    //return tex2D( Head_red, Tex ) * float4(1,1,1,alpha);
	}
	return 0;
}

#define DRAWALPHA \
		ZENABLE = TRUE;\
		ZWRITEENABLE = FALSE;\
		CULLMODE = NONE;\
		ALPHABLENDENABLE = TRUE;\
		SRCBLEND=SRCALPHA;\
		DESTBLEND=INVSRCALPHA;

#define DRAWONE \
		ZENABLE = TRUE;\
		ZWRITEENABLE = FALSE;\
		CULLMODE = NONE;\
		ALPHABLENDENABLE = TRUE;\
		SRCBLEND=SRCALPHA;\
		DESTBLEND=ONE;
		
technique MainTec < string MMDPass = "object"; > {
    pass DrawObject_Base0 {
		
		DRAWONE
		
        VertexShader = compile vs_3_0 Mask_VS(0);
        PixelShader  = compile ps_3_0 Mask_PS(0);
    }
    pass DrawObject_Base1 {
		
		DRAWONE
		
        VertexShader = compile vs_3_0 Mask_VS(1);
        PixelShader  = compile ps_3_0 Mask_PS(0);
    }
    /*
    pass DrawObject_Head {
		
		DRAWONE
		
        VertexShader = compile vs_3_0 Mask_VS(2);
        PixelShader  = compile ps_3_0 Mask_PS(2);
    }
    pass DrawObject_Base_red0 {
		
		DRAWALPHA
		
        VertexShader = compile vs_3_0 Mask_VS(3);
        PixelShader  = compile ps_3_0 Mask_PS(1);
    }
    pass DrawObject_Base_red1 {
		
		DRAWALPHA
		
        VertexShader = compile vs_3_0 Mask_VS(4);
        PixelShader  = compile ps_3_0 Mask_PS(1);
    }
    pass DrawObject_Head_red {
		
		DRAWALPHA
		
        VertexShader = compile vs_3_0 Mask_VS(5);
        PixelShader  = compile ps_3_0 Mask_PS(3);
    }
    */
}

