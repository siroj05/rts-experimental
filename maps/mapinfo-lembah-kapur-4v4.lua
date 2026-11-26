-- Dibuat tools/buat_lembah_kapur.py (seed 1). Aturan: docs/aturan-peta.md.
return {
    name = "Limestone Valley 4v4",
    version = "1.0",
    description = "Four bases per side behind broken limestone ridges, a winding gravel river and a contested island.",
    author = "RTS PC",
    modtype = 3,
    depend = {"Map Helper v1"},
    mapfile = "maps/lembah-kapur-4v4.smf",
    notDeformable = false,
    gravity = 100,
    maxMetal = 1.0,
    extractorRadius = 56,
    teams = {
        [0] = {startPos = {x = 1197, z = 1680}},
        [1] = {startPos = {x = 1707, z = 4156}},
        [2] = {startPos = {x = 1615, z = 6515}},
        [3] = {startPos = {x = 1389, z = 9724}},
        [4] = {startPos = {x = 11091, z = 10608}},
        [5] = {startPos = {x = 10581, z = 8132}},
        [6] = {startPos = {x = 10673, z = 5773}},
        [7] = {startPos = {x = 10899, z = 2564}},
    },
    terrainTypes = {
        [0] = {name = "Meadow", receiveTracks = true, hardness = 1.0},
        [2] = {name = "Deep River", receiveTracks = false, moveSpeeds = {tank = 0, kbot = 0, hover = 0, ship = 1}},
    },
    grass = {bladeHeight = 3.0, bladeWidth = 0.28, bladeWaveScale = 0.8, bladeColor = {0.33, 0.41, 0.24}},
    lighting = {
        -- Matahari dari utara, elevasi ±38° (aturan-peta.md bagian 6). Tahap 6: matahari hangat, bayangan dan
        -- ambient sejuk kebiruan supaya kontras (arah visual natural dan dramatis).
        sunDir = {-0.32, 0.62, -0.71},
        groundAmbientColor = {0.29, 0.33, 0.41},
        groundDiffuseColor = {1.00, 0.92, 0.77},
        groundSpecularColor = {0.10, 0.09, 0.08},
        groundShadowDensity = 0.90,
        unitAmbientColor = {0.33, 0.37, 0.45},
        unitDiffuseColor = {1.00, 0.94, 0.82},
        unitSpecularColor = {0.55, 0.53, 0.50},
        unitShadowDensity = 0.88,
    },
    atmosphere = {
        -- Skybox buatan sendiri (tools/buat_langit.py). Warna kabut = kabut cakrawala skybox.
        skyBox = "langit.dds",
        fogStart = 0.30, fogEnd = 1.0, fogColor = {0.69, 0.75, 0.80},
        skyColor = {0.45, 0.58, 0.76}, sunColor = {1.0, 0.92, 0.78}, minWind = 5, maxWind = 12,
        cloudDensity = 0.0,
    },
    water = {
        -- Sungai pegunungan: hijau toska jernih. Penyerapan rendah supaya dasar kerikil di dangkalan terlihat.
        surfaceColor = {0.50, 0.66, 0.62}, surfaceAlpha = 0.32,
        -- Tanpa bidang air tak hingga: di luar tepi peta yang terlihat adalah kabut bawah skybox.
        hasWaterPlane = false,
        baseColor = {0.40, 0.49, 0.43}, minColor = {0.09, 0.17, 0.17},
        absorb = {0.0105, 0.0068, 0.0058},
        diffuseColor = {0.85, 0.92, 0.88}, diffuseFactor = 1.0,
        specularColor = {1.0, 0.95, 0.85}, specularPower = 48, specularFactor = 0.55,
        fresnelMin = 0.12, fresnelMax = 0.55, fresnelPower = 4.0,
        reflectionDistortion = 0.7, blurBase = 2.0, blurExponent = 1.5,
        perlinStartFreq = 10.0, perlinLacunarity = 2.6, perlinAmplitude = 0.55,
        shoreWaves = false,
    },
    smf = {minheight = -28, maxheight = 857},
    resources = {
        -- Tahap 4: normal detail ruang tangen (A = kekuatan) dan specular (A x 16 = eksponen)
        detailNormalTex = "normal_detail.dds",
        specularTex = "spekular.dds",
        -- Tahap 5: DNTS (R rumput, G tanah, B kerikil, A batu); A ubin = detail terang-gelap
        splatDistrTex = "splat_campur.tga",
        splatDetailNormalTex1 = "dnts_rumput.tga",
        splatDetailNormalTex2 = "dnts_tanah.tga",
        splatDetailNormalTex3 = "dnts_kerikil.tga",
        splatDetailNormalTex4 = "dnts_batu.tga",
        splatDetailNormalDiffuseAlpha = true,
    },
    splats = {
        texScales = {0.0208, 0.0125, 0.0250, 0.0078},
        texMults = {1.0, 1.0, 1.0, 1.0},
    },
}
