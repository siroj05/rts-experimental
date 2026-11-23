// Pakai dependensi konverter v2 untuk membaca meshopt tanpa mengubah hierarki.
import { createRequire } from 'node:module'

const require = createRequire(new URL('../../rts-pc-v2/Tools/aset/package.json', import.meta.url))
const { NodeIO } = require('@gltf-transform/core')
const { ALL_EXTENSIONS } = require('@gltf-transform/extensions')
const { MeshoptDecoder, MeshoptSimplifier } = require('meshoptimizer')
const [, , source, output, ratio, piecePrefix] = process.argv

await Promise.all([MeshoptDecoder.ready, MeshoptSimplifier.ready])
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS)
    .registerDependencies({ 'meshopt.decoder': MeshoptDecoder })
const document = await io.read(source)
for (const extension of document.getRoot().listExtensionsUsed()) {
    if (extension.extensionName === 'EXT_meshopt_compression') extension.dispose()
}
if (ratio !== undefined) {
    const root = document.getRoot()
    const meshes = piecePrefix
        ? root.listNodes().filter(node => node.getName().startsWith(piecePrefix)).map(node => node.getMesh())
        : root.listMeshes()
    for (const mesh of meshes) {
        for (const primitive of mesh.listPrimitives()) {
            const indices = primitive.getIndices()
            const positions = primitive.getAttribute('POSITION').getArray()
            const normals = primitive.getAttribute('NORMAL').getArray()
            const uv = primitive.getAttribute('TEXCOORD_0')?.getArray()
            const count = positions.length / 3
            const attributes = new Float32Array(count * 5)
            for (let vertex = 0; vertex < count; vertex++) {
                attributes.set(normals.subarray(vertex * 3, vertex * 3 + 3), vertex * 5)
                if (uv) attributes.set(uv.subarray(vertex * 2, vertex * 2 + 2), vertex * 5 + 3)
            }
            const input = new Uint32Array(indices.getArray())
            const target = Math.max(24, Math.floor(input.length * Number(ratio) / 3) * 3)
            if (target >= input.length) continue
            const [reduced] = MeshoptSimplifier.simplifyWithAttributes(
                input, positions, 3, attributes, 5, [0.15, 0.15, 0.15, 0.35, 0.35],
                null, target, 0.05, ['Permissive'],
            )
            primitive.setIndices(indices.clone().setArray(new Uint32Array(reduced)))
        }
    }
}
await io.write(output, document)
