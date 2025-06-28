#!/usr/bin/env bash
#
# Description: A Bench Script by Teddysun
# URL: https://teddysun.com/444.html
#         https://github.com/teddysun/across/blob/master/bench.sh
# ------------------------------------------------------------------
#  This version is customised: speed() list trimmed to St‑Petersburg
# ------------------------------------------------------------------

# ------------------------------------------------------------
#  Custom St‑Petersburg server list
# ------------------------------------------------------------
speed() {
    speed_test '18570' 'RETN Saint Petersburg'
    speed_test '31126' 'Nevalink Ltd. Saint Petersburg'
    speed_test '16125' 'Selectel Saint Petersburg'
    speed_test '69069' 'Aeza.net Saint Petersburg'
    speed_test '21014' 'P.A.K.T. LLC Saint Petersburg'
    speed_test '4247'  'MTS Saint Petersburg'
    speed_test '6051'  't2 Russia Saint Petersburg'
    speed_test '17039' 'MegaFon Saint Petersburg'
}

# -------------  EVERYTHING BELOW IS UNCHANGED ORIGINAL SCRIPT -------------
#  ... (the entire original bench.sh content should follow here) ...
#  To keep this example short, please copy the unmodified original script 
#  content from https://raw.githubusercontent.com/teddysun/across/master/bench.sh
#  and replace only the speed() function above.
# --------------------------------------------------------------------------
