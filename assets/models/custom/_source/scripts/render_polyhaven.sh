#!/bin/bash
# Contact sheet di ogni categoria di polyhaven/ in _previews/polyhaven_<categoria>.png (UNO ALLA VOLTA).
cd "$(dirname "$0")/../.."
mkdir -p _previews
r() { out=$1; cols=$2; shift 2; timeout 400 nice blender -b --factory-startup -P _source/scripts/render_group.py -- _previews/$out $cols "$@" 2>&1 | grep -E "RENDERED|Error|Traceback"; }
r polyhaven_rocce.png 4 polyhaven/rocce/*/*.gltf
r polyhaven_alberi.png 3 polyhaven/alberi/*/*.gltf
r polyhaven_fauna.png 1 polyhaven/fauna/*/*.gltf
r polyhaven_oggetti.png 5 polyhaven/oggetti/*/*.gltf
r polyhaven_attrezzi.png 6 polyhaven/attrezzi/*/*.gltf polyhaven/attrezzi_fuori_epoca/*/*.gltf
r polyhaven_molo.png 4 polyhaven/architettura/modular_wooden_pier/*.gltf
r polyhaven_forte.png 6 polyhaven/architettura/modular_fort_01/*.gltf
r polyhaven_navi_fuori_epoca.png 1 polyhaven/navi_fuori_epoca/*/*.gltf
r polyhaven_vegetazione_1.png 8 polyhaven/vegetazione/fern_02/*.gltf polyhaven/vegetazione/grass_medium_01/*.gltf polyhaven/vegetazione/grass_medium_02/*.gltf polyhaven/vegetazione/periwinkle_plant/*.gltf
r polyhaven_vegetazione_2.png 8 polyhaven/vegetazione/celandine_01/*.gltf polyhaven/vegetazione/dandelion_01/*.gltf polyhaven/vegetazione/flower_heliophila/*.gltf polyhaven/vegetazione/othonna_cerarioides/*.gltf polyhaven/vegetazione/searsia_lucida/*.gltf
echo FINE
