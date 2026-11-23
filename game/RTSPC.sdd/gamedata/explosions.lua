local function particles(texture, colors, options)
    options.texture = texture
    options.colormap = colors
    return {
        class = "CSimpleParticleSystem",
        count = 1,
        air = true,
        ground = true,
        unit = true,
        properties = options,
    }
end

return {
    rts_medium_muzzle = {
        usedefaultexplosions = false,
        core = particles("circularthingy", "1 0.97 0.74 0.71   0.81 0.50 0.17 0.34   0 0 0 0", {
            airdrag = 0.72, emitrot = 0, emitrotspread = 4, emitvector = "dir",
            gravity = "0,0,0", numparticles = 2, particlelife = 3, particlelifespread = 2,
            particlesize = 7, particlesizespread = 3, particlespeed = 3.8, particlespeedspread = 2,
            pos = "0,0,0", sizegrowth = -0.1, sizemod = 1,
        }),
        flash = particles("flame", "1 0.96 0.65 0.78   0.70 0.28 0.07 0.30   0 0 0 0", {
            airdrag = 0.7, directional = true, emitrot = 0, emitrotspread = 14, emitvector = "dir",
            gravity = "0,0,0", numparticles = 6, particlelife = 3, particlelifespread = 3,
            particlesize = 6, particlesizespread = 6, particlespeed = 4, particlespeedspread = 4,
            pos = "0,0,0", sizegrowth = 0.3, sizemod = 1,
        }),
        smoke = particles("ismoke06", "0.28 0.27 0.26 0.37   0.14 0.14 0.14 0.23   0 0 0 0", {
            airdrag = 0.88, emitrot = 0, emitrotspread = 30, emitvector = "dir",
            gravity = "0,0.025,0", numparticles = 7, particlelife = 20, particlelifespread = 10,
            particlesize = 3, particlesizespread = 5, particlespeed = 2, particlespeedspread = 3,
            pos = "0,0,0", sizegrowth = 0.49, sizemod = 1,
        }),
    },
    rts_medium_trail = {
        usedefaultexplosions = false,
        smoke = particles("ismoke03", "0.27 0.27 0.26 0.27   0.11 0.11 0.11 0.13   0 0 0 0", {
            airdrag = 0.89, emitrot = 0, emitrotspread = 20, emitvector = "dir",
            gravity = "0,0.018,0", numparticles = 1, particlelife = 14, particlelifespread = 6,
            particlesize = 2, particlesizespread = 1, particlespeed = 0.22, particlespeedspread = 0.2,
            pos = "0,0,0", sizegrowth = 0.23, sizemod = 1,
        }),
    },
    rts_artileri_trail = {
        usedefaultexplosions = false,
        smoke = particles("ismoke06", "0.59 0.58 0.56 0.43   0.37 0.37 0.35 0.25   0 0 0 0", {
            airdrag = .94, emitrot = 0, emitrotspread = 14, emitvector = "0,1,0",
            gravity = "0.018,0.032,0.01", numparticles = 1, particlelife = 86, particlelifespread = 12,
            particlesize = 2.1, particlesizespread = 1.1, particlespeed = .12, particlespeedspread = .15,
            pos = "0,0,0", sizegrowth = .24, sizemod = 1,
        }),
    },
    rts_kecil_muzzle = {
        usedefaultexplosions = false,
        flash = particles("flame", "1 .92 .63 .8   .72 .32 .09 .32   0 0 0 0", {
            airdrag = .8, directional = true, emitrot = 0, emitrotspread = 15, emitvector = "dir",
            gravity = "0,0,0", numparticles = 3, particlelife = 2, particlelifespread = 2,
            particlesize = 2.7, particlesizespread = 1.5, particlespeed = 2, particlespeedspread = 1.2,
            pos = "0,0,0", sizegrowth = .12, sizemod = 1,
        }),
    },
    rts_medium_hit = {
        usedefaultexplosions = false,
        flash = particles("flame", "1 0.94 0.70 0.85   0.75 0.27 0.07 0.35   0 0 0 0", {
            airdrag = 0.8, emitrot = 35, emitrotspread = 30, emitvector = "0,1,0",
            gravity = "0,0,0", numparticles = 4, particlelife = 5, particlelifespread = 5,
            particlesize = 10, particlesizespread = 7, particlespeed = 3, particlespeedspread = 2,
            pos = "0,2,0", sizegrowth = 0.8, sizemod = 1,
        }),
        percikan = particles("circularthingy", "1 0.86 0.47 0.65   0.58 0.23 0.07 0.28   0 0 0 0", {
            airdrag = 0.91, directional = true, emitrot = 51, emitrotspread = 36, emitvector = "0,1,0",
            gravity = "0,-0.23,0", numparticles = 22, particlelife = 9, particlelifespread = 14,
            particlesize = 1.7, particlesizespread = 2.5, particlespeed = 4, particlespeedspread = 7,
            pos = "0,2,0", sizegrowth = -0.04, sizemod = 1,
        }),
        debu = particles("ismoke03", "0.33 0.27 0.19 0.45   0.22 0.19 0.15 0.30   0 0 0 0", {
            airdrag = 0.90, emitrot = 59, emitrotspread = 29, emitvector = "0,1,0",
            gravity = "0,0.03,0", numparticles = 17, particlelife = 28, particlelifespread = 17,
            particlesize = 6, particlesizespread = 8, particlespeed = 3.4, particlespeedspread = 4.1,
            pos = "0,2,0", sizegrowth = 0.61, sizemod = 1,
        }),
        asap = particles("ismoke06", "0.21 0.19 0.17 0.52   0.15 0.14 0.13 0.36   0 0 0 0", {
            airdrag = 0.93, emitrot = 27, emitrotspread = 29, emitvector = "0,1,0",
            gravity = "0.015,0.04,0", numparticles = 11, particlelife = 35, particlelifespread = 15,
            particlesize = 4, particlesizespread = 6, particlespeed = 2.7, particlespeedspread = 3.6,
            pos = "0,3,0", sizegrowth = 0.48, sizemod = 1,
        }),
    },
}
