shader_type canvas_item;

// 架招白閃：把角色像素往白色混，保留原有 alpha 輪廓。
// 只用一個 uniform 驅動，著色器本身不改貼圖、不加節點，池化與重複進出場景都安全。
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), flash), tex.a);
}
