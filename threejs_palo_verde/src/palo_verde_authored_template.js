export const DESERT_MUSEUM_HERO_TEMPLATE = Object.freeze({
  schema: 'palo-verde-hero-template/1',
  id: 'desert_museum_hero_a',
  units: 'meters_at_mature_envelope',
  matureEnvelope: { heightM: 7.55, spreadM: 7.95 },
  intent: 'illustrator-authored silhouette and branch gesture with bounded procedural variation',
  leaders: [
    { id: 'leader_left', points: [[-0.04,0,0.02],[-0.11,0.92,0.03],[-0.36,2.05,0.08],[-0.66,3.02,0.20]], radii: [0.150,0.052] },
    { id: 'leader_right', points: [[0.05,0,-0.02],[0.12,0.88,-0.04],[0.38,1.98,-0.18],[0.58,2.83,-0.34]], radii: [0.142,0.050] },
    { id: 'leader_center', points: [[0.00,0,0.06],[0.02,1.02,0.15],[0.08,2.24,0.42],[0.18,3.22,0.62]], radii: [0.146,0.050] }
  ],
  scaffolds: [
    { id:'left_low', parent:'leader_left', attach:0.46, end:[-3.28,4.10,0.72], arch:0.070, sway:-0.030, radiusScale:0.52 },
    { id:'left_mid', parent:'leader_left', attach:0.64, end:[-3.02,5.18,-0.76], arch:0.085, sway:0.038, radiusScale:0.47 },
    { id:'left_high', parent:'leader_left', attach:0.81, end:[-2.10,6.18,1.08], arch:0.105, sway:-0.032, radiusScale:0.43 },
    { id:'left_rear', parent:'leader_left', attach:0.70, end:[-1.58,5.38,-2.18], arch:0.078, sway:0.040, radiusScale:0.42 },
    { id:'right_low', parent:'leader_right', attach:0.47, end:[3.30,4.16,-0.56], arch:0.070, sway:0.030, radiusScale:0.52 },
    { id:'right_mid', parent:'leader_right', attach:0.65, end:[2.92,5.25,0.96], arch:0.087, sway:-0.040, radiusScale:0.47 },
    { id:'right_high', parent:'leader_right', attach:0.82, end:[2.02,6.14,-1.26], arch:0.102, sway:0.032, radiusScale:0.43 },
    { id:'right_front', parent:'leader_right', attach:0.68, end:[1.50,5.18,2.14], arch:0.080, sway:-0.036, radiusScale:0.42 },
    { id:'top_center', parent:'leader_center', attach:0.78, end:[0.12,6.82,0.22], arch:0.115, sway:0.018, radiusScale:0.46 },
    { id:'top_front', parent:'leader_center', attach:0.64, end:[-0.30,5.92,2.38], arch:0.092, sway:0.035, radiusScale:0.42 },
    { id:'top_rear', parent:'leader_center', attach:0.62, end:[0.34,5.90,-2.34], arch:0.090, sway:-0.034, radiusScale:0.42 }
  ],
  canopyRegions: [
    { id:'left_low_inner', branch:'left_low', t:0.56, offset:[-0.05,0.10,0.06], size:[1.46,0.88,1.04], planes:14, tone:'shadow' },
    { id:'left_low_outer', branch:'left_low', t:0.91, offset:[-0.04,0.10,0.02], size:[1.78,0.98,1.18], planes:18, tone:'mid' },
    { id:'left_mid_inner', branch:'left_mid', t:0.56, offset:[-0.04,0.08,-0.04], size:[1.48,0.86,1.08], planes:14, tone:'shadow' },
    { id:'left_mid_outer', branch:'left_mid', t:0.90, offset:[-0.04,0.12,-0.02], size:[1.82,1.02,1.28], planes:18, tone:'mid' },
    { id:'left_high_bridge', branch:'left_high', t:0.56, offset:[-0.02,0.07,0.02], size:[1.38,0.82,1.00], planes:12, tone:'mid' },
    { id:'left_high_outer', branch:'left_high', t:0.91, offset:[-0.02,0.12,0.04], size:[1.72,1.00,1.20], planes:17, tone:'light' },
    { id:'left_rear_outer', branch:'left_rear', t:0.88, offset:[-0.02,0.10,-0.03], size:[1.62,0.94,1.22], planes:16, tone:'shadow' },

    { id:'right_low_inner', branch:'right_low', t:0.56, offset:[0.05,0.10,-0.05], size:[1.46,0.88,1.02], planes:14, tone:'shadow' },
    { id:'right_low_outer', branch:'right_low', t:0.91, offset:[0.04,0.10,-0.02], size:[1.80,0.98,1.16], planes:18, tone:'mid' },
    { id:'right_mid_inner', branch:'right_mid', t:0.56, offset:[0.04,0.08,0.04], size:[1.46,0.86,1.06], planes:14, tone:'mid' },
    { id:'right_mid_outer', branch:'right_mid', t:0.90, offset:[0.04,0.12,0.02], size:[1.82,1.02,1.28], planes:18, tone:'light' },
    { id:'right_high_bridge', branch:'right_high', t:0.56, offset:[0.02,0.07,-0.02], size:[1.38,0.82,1.00], planes:12, tone:'mid' },
    { id:'right_high_outer', branch:'right_high', t:0.91, offset:[0.02,0.12,-0.04], size:[1.72,1.00,1.20], planes:17, tone:'light' },
    { id:'right_front_outer', branch:'right_front', t:0.88, offset:[0.03,0.10,0.04], size:[1.58,0.92,1.20], planes:16, tone:'mid' },

    { id:'top_center_inner', branch:'top_center', t:0.64, offset:[0.00,0.08,0.00], size:[1.44,0.88,1.02], planes:14, tone:'mid' },
    { id:'top_center_cap', branch:'top_center', t:0.94, offset:[0.00,0.08,0.00], size:[1.68,0.96,1.14], planes:17, tone:'light' },
    { id:'top_front_outer', branch:'top_front', t:0.88, offset:[-0.02,0.10,0.04], size:[1.58,0.94,1.22], planes:16, tone:'light' },
    { id:'top_rear_outer', branch:'top_rear', t:0.88, offset:[0.02,0.10,-0.04], size:[1.58,0.94,1.22], planes:16, tone:'shadow' }
  ],
  negativeSpaces: [
    { id:'lower_vase_opening', center:[0,3.85,0.00], radius:[0.95,0.75,0.85] },
    { id:'upper_left_window', center:[-1.20,5.70,0.10], radius:[0.55,0.46,0.50] },
    { id:'upper_right_window', center:[1.20,5.66,-0.05], radius:[0.50,0.44,0.48] }
  ],
  variation: { branchControlM:0.055, branchEndM:0.075, regionCenterM:0.060, regionScale:0.055, maxAzimuthRad:0.025 }
});

export function validateHeroTemplate(template=DESERT_MUSEUM_HERO_TEMPLATE){
  const errors=[];
  if(template?.schema!=='palo-verde-hero-template/1')errors.push('unsupported template schema');
  if(template?.leaders?.length!==3)errors.push('exactly three primary leaders required');
  if(!Array.isArray(template?.scaffolds)||template.scaffolds.length<9||template.scaffolds.length>14)errors.push('hero scaffold count out of authored range');
  if(!Array.isArray(template?.canopyRegions)||template.canopyRegions.length<14)errors.push('insufficient authored canopy regions');
  const ids=new Set();
  for(const leader of template?.leaders||[]){if(ids.has(leader.id))errors.push(`duplicate id ${leader.id}`);ids.add(leader.id);if(!Array.isArray(leader.points)||leader.points.length!==4)errors.push(`${leader.id} needs cubic points`);}
  for(const scaffold of template?.scaffolds||[]){if(ids.has(scaffold.id))errors.push(`duplicate id ${scaffold.id}`);if(!ids.has(scaffold.parent))errors.push(`${scaffold.id} parent missing`);ids.add(scaffold.id);if(!(scaffold.attach>0&&scaffold.attach<1))errors.push(`${scaffold.id} attach invalid`);}
  const regionIds=new Set();
  for(const region of template?.canopyRegions||[]){if(regionIds.has(region.id))errors.push(`duplicate region ${region.id}`);regionIds.add(region.id);if(!ids.has(region.branch))errors.push(`${region.id} branch missing`);if(!(region.t>0&&region.t<=1))errors.push(`${region.id} t invalid`);if(!Array.isArray(region.size)||region.size.some(v=>!(v>0)))errors.push(`${region.id} size invalid`);if(!(region.planes>=8&&region.planes<=30))errors.push(`${region.id} plane count invalid`);if(!['shadow','mid','light'].includes(region.tone))errors.push(`${region.id} tone invalid`);}
  if(errors.length)throw new Error(errors.join('; '));
  return true;
}
