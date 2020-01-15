
float4 PS_Stealth() : COLOR {
    return float4(0.1, 0.1, 0.1, 0.09);
}
technique Stealth {
    pass Single_Pass { PixelShader = compile ps_2_0 PS_Stealth(); }
}
technique StealthSS < string MMDPass = "object_ss"; > {
	pass Single_Pass { PixelShader = compile ps_2_0 PS_Stealth(); }
}
