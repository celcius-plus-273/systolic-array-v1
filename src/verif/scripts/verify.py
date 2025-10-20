import click as ck
import numpy as np

from pathlib import Path
from util import *

@ck.command()
@ck.option('-d', '--dim', type=(int, int, int), help='Matrix Array Dimensions (M, K, N): (M,K) * (K,N) = (M,N)')
@ck.option('-p', '--path', type=str, default='bin', help='Path to output directory. E.g. path/to/bin')
@ck.option('-n', '--numtests', type=int, default=1, help='Number of tests')
@ck.option('-v', '--verbose', is_flag=True)
def main(dim, path, numtests, verbose):
    # args
    M, K, N = dim

    # summarize all results to single output
    f = open('verif_summary.log', 'w')
    result = ''
    num_passed = 0
    passed = False

    for i in range(numtests):

        dir_path = Path(path) / f'random/test_{i}'

        if not dir_path.exists():
            print(f'[ERROR]: Results does not exist on path: {dir_path}')
            result += f'Test {i}: UNSUCCESFUL\n'
            continue

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
            if verbose:
                ck.echo('====================')
                ck.echo('====== PASSED ======')
                ck.echo('====================')
            passed = True
            num_passed += 1
        else:
            if verbose:
                ck.echo('====================')
                ck.echo('====== FAILED ======')
                ck.echo('====================')
        
        if passed:
            result += f'Test {i}: PASSED\n'
        else:
            result += f'Test {i}: FAILED\n'

    # print summary and individual results
    f.write(f'----- Summary -----\n')
    f.write(f'Total Tests: {numtests}\n')
    f.write(f'Passed Tests: {num_passed}\n')
    f.write(f'Grade: {(float(num_passed)/numtests)*100 :.2f}\n')
    f.write(f'\n----- Results -----\n')
    f.write(result)

if __name__ == '__main__':
    main()