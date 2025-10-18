import numpy as np
import click as ck
import sys

from util import *
from pathlib import Path

# simulate the matrix mult with overflow saturation
def overflow_matmul(A, B, M, N, K):
    # output matrix
    C = np.zeros((M, N), dtype=int)

    f = open('temp.log', 'w')

    # simply do a loop nest output stationary representatio (easier to model)
    # let m = row pointer
    # let n = col pointer
    # output dimensions is MxN
    for m in range(M):
        for n in range(N):
            f.write(f'Output Matrix [{m}][{n}]\n')
            # each output result uses all the k psum values
            psum = 0
            for k in range(K):
                act = A[m][k]
                weight = B[k][n]
                prod = np.clip(act * weight, -128, 127)
                psum = np.clip(psum + prod, -128, 127)
                f.write(f'k index = {k}\n')
                f.write(f'{act} * {weight} = {prod}\n')
                f.write(f'acc_psum = {psum}\n')

            # write output act/psum to index m, n
            C[m][n] = psum

    return C

@ck.command()
@ck.option('-d', '--dim', type=(int, int, int), help='Matrix Array Dimensions: (M,K) * (K,N) = (M,N)')
@ck.option('-b', '--bound', type=(int, int), help='Lower and upper bounds for matrix values')
@ck.option('-p', '--path', type=str, default='bin', help='Path to output directory. E.g. path/to/bin')
@ck.option('-v', '--verbose', is_flag=True)
def main(dim, bound, path, verbose):
    # args
    M, N, K = dim

    # need to generate 4x4 weight matrix and 4x4 input matrix (with staggering)
    low, high = bound
    weight_matrix = random_matrix((low, high), (K, N))
    input_matrix = random_matrix((low, high), (M, K))
    stag_input_matrix = matrix_to_stagger(input_matrix)

    # output_matrix = np.matmul(input_matrix, weight_matrix)
    output_matrix = overflow_matmul(input_matrix, weight_matrix, M, N, K)

    # output paths
    dir_path = Path(path)
    golden_path = dir_path / 'output_golden.hex'
    input_path = dir_path / 'input_rom.hex'
    weight_path = dir_path / 'weight_rom.hex'

    to_bin(str(weight_path), vertical_flip(weight_matrix), K, N)
    to_bin(str(input_path), horizontal_flip(stag_input_matrix), M + K -1, K)
    to_bin(str(golden_path), horizontal_flip(output_matrix), M, N)

    # verbose print
    if verbose:
        ck.echo('------ Input Act ------')
        ck.echo(input_matrix)
        ck.echo('------ Weights ------')
        ck.echo(weight_matrix)

if __name__ == '__main__':
    main()