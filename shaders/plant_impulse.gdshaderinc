// Four independent, damped elastic impacts. Shared by original plant and added stalks.
uniform vec3 impact_centers[4];
uniform vec3 impact_pivots[4];
uniform vec3 impact_offsets[4];
uniform vec3 impact_rotations[4];
uniform float impact_radii[4];
uniform mat4 plant_from_world;
vec3 elastic_plant_position(vec3 world) {
 vec3 displacement=vec3(0.0);
 float anchored=smoothstep(0.025,0.25,(plant_from_world*vec4(world,1.0)).y);
 for(int i=0;i<4;i++) {
  vec3 distance=world-impact_centers[i];
  float influence=exp(-dot(distance,distance)/max(impact_radii[i]*impact_radii[i],0.0001));
  displacement+=(impact_offsets[i]+cross(impact_rotations[i],world-impact_pivots[i]))*influence;
 }
 return world+displacement*anchored;
}
