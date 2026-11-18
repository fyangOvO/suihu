shader_type canvas_item;
render_mode blend_mix;

// 角色可讀性層（OPT-06）：輪廓光 rim + 架招白閃 flash。
// - rim：取 alpha 鄰域的「外沿」畫一圈敵我配色，讓剪影從暗背景剝出來；
// - 攻擊前搖時由 rigged_fighter 把 rim_energy 推高，用輪廓亮度提示出手，不畫紅圈；
// - flash：原 white_flash.gdshader 的行為，架招成立時把像素往白混。
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.72, 0.82, 0.92, 1.0);
uniform float rim_energy : hint_range(0.0, 2.0) = 0.0;
uniform float rim_width : hint_range(0.0, 4.0) = 1.8;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;
	float edge = 0.0;
	// 8 方向取 alpha，成本低且不會把整張圖糊掉
	edge = max(edge, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(px.x, px.y) * 0.7).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(-px.x, -px.y) * 0.7).a);
	// 只保留角色外沿（內部 alpha 已滿 -> 差值 0）
	edge = clamp(edge - tex.a, 0.0, 1.0) * clamp(rim_energy, 0.0, 1.0);

	vec4 col = tex;
	col.rgb = mix(col.rgb, rim_color.rgb, edge);
	col.a = max(col.a, edge * rim_color.a);
	col.rgb = mix(col.rgb, vec3(1.0), flash);
	COLOR = col;
}
