export const DESERT_MUSEUM_HERO_TEMPLATE = Object.freeze({
  schema: 'palo-verde-hero-template/1',
  id: 'desert_museum_hero_b',
  units: 'meters_at_mature_envelope',
  matureEnvelope: { heightM: 7.55, spreadM: 7.95 },
  intent: 'illustrator-authored silhouette and branch gesture with bounded procedural variation',
  leaders: [
    { id: 'leader_left', points: [[-0.04,0,0.02],[-0.10,0.92,0.03],[-0.34,2.03,0.08],[-0.64,3.00,0.18]], radii: [0.150,0.052] },
    { id: 'leader_right', points: [[0.05,0,-0.02],[0.12,0.88,-0.04],[0.36,1.96,-0.17],[0.56,2.82,-0.32]], radii: [0.142,0.050] },
    { id: 'leader_center', points: [[0.00,0,0.06],[0.02,1.02,0.15],[0.08,2.22,0.40],[0.18,3.20,0.60]], radii: [0.146,0.050] }
  ],
  scaffolds: [
    { id:'left_low', parent:'leader_left', attach:0.46, controls:[[-0.56,2.18,0.12],[-1.96,3.42,0.48],[-3.18,4.16,0.82]], radiusScale:0.52 },
    { id:'left_mid', parent:'leader_left', attach:0.63, controls:[[-0.66,2.74,-0.10],[-1.86,4.42,-0.58],[-2.86,5.34,-0.82]], radiusScale:0.47 },
    { id:'left_high', parent:'leader_left', attach:0.80, controls:[[-0.82,3.30,0.24],[-1.36,5.14,0.72],[-1.94,6.22,1.02]], radiusScale:0.43 },
    { id:'left_rear', parent:'leader_left', attach:0.69, controls:[[-0.58,2.80,-0.42],[-1.08,4.46,-1.46],[-1.52,5.42,-2.18]], radiusScale:0.42 },
    { id:'right_low', parent:'leader_right', attach:0.47, controls:[[0.62,2.20,-0.10],[2.02,3.44,-0.40],[3.18,4.18,-0.62]], radiusScale:0.52 },
    { id:'right_mid', parent:'leader_right', attach:0.64, controls:[[0.70,2.76,0.06],[1.90,4.46,0.66],[2.88,5.34,0.94]], radiusScale:0.47 },
    { id:'right_high', parent:'leader_right', attach:0.81, controls:[[0.86,3.28,-0.34],[1.40,5.14,-0.88],[1.98,6.18,-1.22]], radiusScale:0.43 },
    { id:'right_front', parent:'leader_right', attach:0.68, controls:[[0.60,2.86,0.44],[1.08,4.42,1.48],[1.48,5.20,2.16]], radiusScale:0.42 },
    { id:'top_center', parent:'leader_center', attach:0.76, controls:[[0.18,3.52,0.52],[0.14,5.52,0.26],[0.10,6.82,0.18]], radiusScale:0.46 },
    { id:'top_front', parent:'leader_center', attach:0.63, controls:[[0.08,3.26,0.82],[-0.10,4.86,1.64],[-0.30,5.94,2.34]], radiusScale:0.42 },
    { id:'top_rear', parent:'leader_center', attach:0.61, controls:[[0.14,3.20,0.10],[0.28,4.82,-1.58],[0.34,5.92,-2.30]], radiusScale:0.42 }
  ],
  canopyRegions: [
    { id:'left_low_body', branch:'left_low', t:0.55, offset:[0.16,0.24,0.02], size:[2.08,1.28,1.54], planes:24, tone:'shadow' },
    { id:'left_low_outer', branch:'left_low', t:0.86, offset:[0.08,0.18,0.00], size:[2.30,1.38,1.70], planes:28, tone:'mid' },
    { id:'left_mid_body', branch:'left_mid', t:0.50, offset:[0.18,0.18,0.08], size:[2.12,1.30,1.60], planes:24, tone:'shadow' },
    { id:'left_mid_outer', branch:'left_mid', t:0.84, offset:[0.08,0.18,0.03], size:[2.34,1.42,1.76], planes:28, tone:'mid' },
    { id:'left_high_body', branch:'left_high', t:0.52, offset:[0.12,0.10,-0.04], size:[1.94,1.24,1.48], planes:22, tone:'mid' },
    { id:'left_high_outer', branch:'left_high', t:0.86, offset:[0.04,0.14,0.02], size:[2.16,1.36,1.62], planes:26, tone:'light' },
    { id:'left_rear_outer', branch:'left_rear', t:0.80, offset:[0.10,0.14,0.12], size:[2.00,1.26,1.62], planes:24, tone:'shadow' },

    { id:'right_low_body', branch:'right_low', t:0.55, offset:[-0.16,0.24,-0.02], size:[2.08,1.28,1.54], planes:24, tone:'shadow' },
    { id:'right_low_outer', branch:'right_low', t:0.86, offset:[-0.08,0.18,0.00], size:[2.30,1.38,1.70], planes:28, tone:'mid' },
    { id:'right_mid_body', branch:'right_mid', t:0.50, offset:[-0.18,0.18,-0.08], size:[2.12,1.30,1.60], planes:24, tone:'mid' },
    { id:'right_mid_outer', branch:'right_mid', t:0.84, offset:[-0.08,0.18,-0.03], size:[2.34,1.42,1.76], planes:28, tone:'light' },
    { id:'right_high_body', branch:'right_high', t:0.52, offset:[-0.12,0.10,0.04], size:[1.94,1.24,1.48], planes:22, tone:'mid' },
    { id:'right_high_outer', branch:'right_high', t:0.86, offset:[-0.04,0.14,-0.02], size:[2.16,1.36,1.62], planes:26, tone:'light' },
    { id:'right_front_outer', branch:'right_front', t:0.78, offset:[-0.10,0.14,-0.10], size:[2.02,1.28,1.64], planes:24, tone:'mid' },

    { id:'top_center_body', branch:'top_center', t:0.52, offset:[0.00,0.06,0.00], size:[1.88,1.22,1.48], planes:22, tone:'mid' },
    { id:'top_center_cap', branch:'top_center', t:0.82, offset:[0.00,0.10,0.00], size:[2.14,1.36,1.62], planes:26, tone:'light' },
    { id:'top_front_outer', branch:'top_front', t:0.76, offset:[0.02,0.14,-0.12], size:[2.02,1.28,1.66], planes:24, tone:'light' },
    { id:'top_rear_outer', branch:'top_rear', t:0.76, offset:[-0.02,0.14,0.12], size:[2.02,1.28,1.66], planes:24, tone:'shadow' }
  ],
  negativeSpaces: [
    { id:'lower_vase_opening', center:[0,3.80,0.00], radius:[0.68,0.54,0.64] },
    { id:'upper_left_window', center:[-1.05,5.72,0.10], radius:[0.34,0.32,0.36] },
    { id:'upper_right_window', center:[1.08,5.68,-0.06], radius:[0.32,0.30,0.34] }
  ],
  variation: { branchControlM:0.045, branchEndM:0.060, regionCenterM:0.045, regionScale:0.045, maxAzimuthRad:0.020 }
});

export function validateHeroTemplate(template=DESERT_MUSEUM_HERO_TEMPLATE){
  const errors=[];
  if(template?.schema!=='palo-verde-hero-template/1')errors.push('unsupported template schema');
  if(template?.leaders?.length!==3)errors.push('exactly three primary leaders required');
  if(!Array.isArray(template?.scaffolds)||template.scaffolds.length<9||template.scaffolds.length>14)errors.push('hero scaffold count out of authored range');
  if(!Array.isArray(template?.canopyRegions)||template.canopyRegions.length<14)errors.push('insufficient authored canopy regions');
  const ids=new Set();
  for(const leader of template?.leaders||[]){if(ids.has(leader.id))errors.push(`duplicate id ${leader.id}`);ids.add(leader.id);if(!Array.isArray(leader.points)||leader.points.length!==4)errors.push(`${leader.id} needs cubic points`);}
  for(const scaffold of template?.scaffolds||[]){if(ids.has(scaffold.id))errors.push(`duplicate id ${scaffold.id}`);if(!ids.has(scaffold.parent))errors.push(`${scaffold.id} parent missing`);ids.add(scaffold.id);if(!(scaffold.attach>0&&scaffold.attach<1))errors.push(`${scaffold.id} attach invalid`);if(!Array.isArray(scaffold.controls)||scaffold.controls.length!==3)errors.push(`${scaffold.id} authored controls missing`);}
  const regionIds=new Set();
  for(const region of template?.canopyRegions||[]){if(regionIds.has(region.id))errors.push(`duplicate region ${region.id}`);regionIds.add(region.id);if(!ids.has(region.branch))errors.push(`${region.id} branch missing`);if(!(region.t>0&&region.t<=1))errors.push(`${region.id} t invalid`);if(!Array.isArray(region.size)||region.size.some(v=>!(v>0)))errors.push(`${region.id} size invalid`);if(!(region.planes>=8&&region.planes<=36))errors.push(`${region.id} plane count invalid`);if(!['shadow','mid','light'].includes(region.tone))errors.push(`${region.id} tone invalid`);}
  if(errors.length)throw new Error(errors.join('; '));
  return true;
}
