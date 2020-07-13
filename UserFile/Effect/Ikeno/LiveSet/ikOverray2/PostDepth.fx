//-----------------------------------------------------------------------------
// 

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// 深度マップ
shared texture PostDepthMapRT: OFFSCREENRENDERTARGET <
	string Description = "depth map for postdepth";
	float4 ClearColor = { 1.0, 0, 0, 1 };
	float2 ViewportRatio = {1, 1};
	float ClearDepth = 1.0;
	string Format = "R16F";
	int MipLevels = 1;
	string DefaultEffect =
		"ConeLights.pmx = hide;"
		"*.pm* = depth.fx;"
		"*.x = depth.fx;"
		"* = hide;";
>;
sampler DepthMap = sampler_state {
	texture = <PostDepthMapRT>;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
	AddressU  = CLAMP; AddressV  = CLAMP;
};

technique PostDepth <
	string Script = 
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"ScriptExternal=Color;"
		"RenderColorTarget0=;"
	;
> {}


//-----------------------------------------------------------------------------

