const STYLE_SCHEMA = 'perspective-plant-style/1';
const SPECIES_SCHEMA = 'perspective-plant-species/1';

export const NORTHSTAR_ANIME_01 = Object.freeze({
  schema: STYLE_SCHEMA,
  id: 'northstar_anime_01',
  intent: 'architectural-anime illustration; painted shape hierarchy before botanical micro-detail',
  shading: {
    tonalBands: 3,
    midBand: [0.40, 0.52],
    highBand: [0.76, 0.88],
    normalUpBias: 0.025,
    heightLightBias: 0.030,
    variationAmount: 0.032,
    ambientEmission: 0.90,
    realisticGradientPriority: 0.10
  },
  linework: {
    mode: 'selective_major_structure',
    trunkSilhouette: 1.0,
    majorBranchSilhouette: 0.64,
    foliageInteriorOutline: 0.0,
    foliageSilhouetteInk: 0.04,
    color: '#40594f'
  },
  shadow: {
    mode: 'painted_contact',
    opacityIntent: 0.18,
    softnessIntent: 0.94,
    visualPriority: 0.16,
    note: 'painted contact shadow replaces detailed realtime foliage projection in the art study'
  },
  hierarchy: {
    largeMass: 1.0,
    mediumBreakup: 0.82,
    smallAccent: 0.26,
    microNoise: 0.03
  }
});

export const DESERT_MUSEUM_PALO_VERDE = Object.freeze({
  schema: SPECIES_SCHEMA,
  id: 'desert_museum_palo_verde',
  commonName: 'Desert Museum Palo Verde',
  botanicalName: "Parkinsonia x 'Desert Museum'",
  category: 'tree',
  generator: 'airy_vase_tree',
  styleProfile: NORTHSTAR_ANIME_01.id,
  identity: {
    read: ['green multi-leader wood', 'open asymmetrical vase crown', 'fine feathery foliage', 'yellow bloom accent'],
    silhouettePriority: 0.96,
    botanicalLiteralism: 0.52,
    negativeSpacePriority: 0.94
  },
  growth: {
    domain: 'illustrative_maturity_0_to_1',
    installed: { heightM: 3.0, spreadM: 2.25 },
    mature: { heightM: 7.55, spreadM: 7.95 },
    calendarCalibrated: false
  },
  structure: {
    leaderCount: 3,
    leaderAzimuth: [-0.15, 2.05, 4.22],
    leaderHeightMatureM: [2.70, 2.25, 3.10],
    leaderReachFraction: [0.11, 0.14, 0.10],
    scaffoldCountMature: 4,
    scaffoldLengthFraction: [0.27, 0.39],
    secondaryCountMature: 4,
    twigCountMature: 2,
    tipBranchProbabilityPattern: 'alternating',
    forkLowBias: 0.88,
    branchArcBias: 0.82,
    droopBias: 0.10,
    taperStrength: 0.92
  },
  canopy: {
    openness: 1.0,
    interiorFill: 0.24,
    massStride: 2,
    massBrushesPerAnchor: [3, 5],
    massWidthM: [0.24, 0.50],
    massAspect: [1.25, 1.85],
    massDepthFraction: [0.20, 0.36],
    massDepthScatter: [0.24, 0.82],
    mediumBreakupScale: [0.48, 0.72],
    fineAccentFraction: 0.62,
    bridgeMassProbability: 0.31,
    avoidSolidCenterRadiusFraction: 0.25
  },
  modules: {
    fineSprig: {
      lengthM: [0.16, 0.26],
      leafletPairs: [5, 7],
      leafletLengthFraction: [0.14, 0.21],
      densityScale: 0.66,
      visibleRole: 'accent_not_mass'
    },
    bloom: {
      probabilityAtTerminal: 0.08,
      sizeFractionOfSprig: [0.07, 0.105],
      visualPriority: 0.10
    }
  },
  material: {
    wood: ['#456f5b', '#759879', '#a5bba0'],
    foliage: ['#526b46', '#7d9158', '#a7b66d'],
    bloom: ['#a08336', '#c3a84a', '#dcc667'],
    outline: '#40584f',
    ground: '#ddd3bf',
    sky: '#dce9e7',
    contactShadow: '#62665a'
  },
  lod0Budget: {
    triangleTarget: 190000,
    triangleHardCap: 280000,
    preferredVisibleMasses: [220, 620],
    preferredFineSprigs: [700, 3000],
    artWinsOverBudgetUntilDeviceTest: true
  }
});

export const TEXAS_SAGE = Object.freeze({
  schema: SPECIES_SCHEMA,
  id: 'texas_sage_generic',
  commonName: 'Texas Sage',
  botanicalName: 'Leucophyllum frutescens',
  category: 'shrub',
  generator: 'dense_woody_mound',
  styleProfile: NORTHSTAR_ANIME_01.id,
  identity: {
    read: ['dense silver-green mound', 'soft outer silhouette', 'little visible woody center', 'restrained lavender bloom'],
    silhouettePriority: 0.90,
    botanicalLiteralism: 0.46,
    negativeSpacePriority: 0.34
  },
  growth: {
    domain: 'illustrative_maturity_0_to_1',
    installed: { heightM: 0.65, spreadM: 0.60 },
    mature: { heightM: 1.83, spreadM: 1.83 },
    calendarCalibrated: false,
    cultivarSpecified: false
  },
  structure: {
    stemCount: 7,
    woodyVisibility: 0.08,
    radialStemBias: 0.88,
    outerBranchDensity: 0.92,
    moundFlattening: 0.18
  },
  canopy: {
    openness: 0.22,
    interiorFill: 0.90,
    massBrushesPerAnchor: [7, 12],
    massWidthM: [0.12, 0.28],
    massAspect: [0.80, 1.34],
    massDepthFraction: [0.28, 0.48],
    massDepthScatter: [0.18, 0.98],
    mediumBreakupScale: [0.58, 0.84],
    fineAccentFraction: 0.76,
    bridgeMassProbability: 0.72,
    avoidSolidCenterRadiusFraction: 0.0
  },
  modules: {
    fineSprig: {
      lengthM: [0.06, 0.13],
      densityScale: 1.0,
      visibleRole: 'surface_texture_and_silhouette'
    },
    bloom: {
      probabilityAtTerminal: 0.08,
      visualPriority: 0.10
    }
  },
  material: {
    wood: ['#5a6255', '#747b68', '#939984'],
    foliage: ['#66766d', '#91a097', '#c1cbc1'],
    bloom: ['#7c668b', '#a788b5', '#cdb5d7'],
    outline: '#59665f',
    ground: '#ddd3bf',
    sky: '#dce9e7',
    contactShadow: '#686a65'
  },
  lod0Budget: {
    triangleTarget: 90000,
    triangleHardCap: 150000,
    preferredVisibleMasses: [220, 650],
    artWinsOverBudgetUntilDeviceTest: true
  }
});

const SPECIES = new Map([
  [DESERT_MUSEUM_PALO_VERDE.id, DESERT_MUSEUM_PALO_VERDE],
  [TEXAS_SAGE.id, TEXAS_SAGE]
]);

export function getSpeciesRecipe(id) {
  const recipe = SPECIES.get(id);
  if (!recipe) throw new Error(`Unknown plant recipe: ${id}`);
  validateSpeciesRecipe(recipe);
  return recipe;
}

export function validateSpeciesRecipe(recipe) {
  const errors = [];
  if (!recipe || recipe.schema !== SPECIES_SCHEMA) errors.push('unsupported species schema');
  if (!recipe?.id || !recipe?.category || !recipe?.generator) errors.push('identity fields missing');
  if (!recipe?.growth?.installed || !recipe?.growth?.mature) errors.push('growth envelope missing');
  for (const key of ['heightM', 'spreadM']) {
    if (!(recipe?.growth?.installed?.[key] > 0) || !(recipe?.growth?.mature?.[key] > 0)) errors.push(`invalid ${key}`);
    if (recipe?.growth?.mature?.[key] < recipe?.growth?.installed?.[key]) errors.push(`${key} cannot shrink toward maturity`);
  }
  if (!Array.isArray(recipe?.material?.foliage) || recipe.material.foliage.length !== 3) errors.push('three-tone foliage palette required');
  if (!Array.isArray(recipe?.material?.wood) || recipe.material.wood.length !== 3) errors.push('three-tone wood palette required');
  if (!(recipe?.lod0Budget?.triangleHardCap > 0)) errors.push('LOD0 hard cap missing');
  if (errors.length) throw new Error(`${recipe?.id || 'recipe'}: ${errors.join('; ')}`);
  return true;
}

export function resolveGrowth(recipe, maturity) {
  validateSpeciesRecipe(recipe);
  const t = Math.max(0, Math.min(1, Number(maturity)));
  const installed = recipe.growth.installed;
  const mature = recipe.growth.mature;
  const lerp = (a, b) => a + (b - a) * t;
  return {
    maturity: t,
    heightM: lerp(installed.heightM, mature.heightM),
    spreadM: lerp(installed.spreadM, mature.spreadM),
    calendarCalibrated: false
  };
}
