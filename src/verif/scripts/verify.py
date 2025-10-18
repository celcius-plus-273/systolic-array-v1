import click as ck
import numpy as np

from pathlib import Path
from util import *

@ck.command()
@ck.option('-d', '--dim', type=(int, int, int), help='Matrix Array Dimensions (M, K, N): (M,K) * (K,N) = (M,N)')
@ck.option('-p', '--path', type=str, default='bin', help='Path to output directory. E.g. path/to/bin')
@ck.option('-v', '--verbose', is_flag=True)
def main(dim, path, verbose):
    # args
    M, K, N = dim
    dir_path = Path(path)

    # check systolic array's output matrix :)
    golden_path = dir_path / 'output_golden.hex'
    if golden_path.exists():
        golden_act = read_golden(str(golden_path), M, N)
        if verbose:
            ck.echo(golden_act)

    output_path = dir_path / 'output_mem.hex'
    if output_path.exists():
        output_act = read_output_mem(str(output_path), M, N)
        if verbose:
            ck.echo(output_act)

    if np.array_equal(output_act, golden_act):
        ck.echo('====================')
        ck.echo('====== PASSED ======')
        ck.echo('====================')
    else:
        ck.echo('====================')
        ck.echo('====== FAILED ======')
        ck.echo('====================')

if __name__ == '__main__':
    main()