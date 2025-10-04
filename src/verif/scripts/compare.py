import numpy as np

def read_output_mem(file, rows, cols):
    B = np.zeros((rows + cols - 1, cols), dtype=int)
    f = open(file, 'r')
    lines = f.readlines()
    for i in range(rows + cols - 1):
        line = lines[i]
        # each line has #cols * 8 bits
        for j in range(cols):
            start = 2*j
            end = (2*j) + 1
            entry = line[start:end+1]
            B[i][j] = int(entry, 16)

    return B

def read_golden(file, rows, cols):
    B = np.zeros((rows, cols), dtype=int)
    f = open(file, 'r')
    lines = f.readlines()
    for i in range(rows):
        line = lines[i]
        # each line has #cols * 8 bits
        for j in range(cols):
            start = 2*j
            end = (2*j) + 1
            entry = line[start:end+1]
            B[i][j] = int(entry, 16)

    return B

def stagger_to_matrix(A, rows, cols):
    # input matrix A must have the following staggered matrix dimensions
    assert A.shape == (rows + cols - 1, cols)

    # revert a staggered matrix
    # i: row pointer
    # j: col pointer
    B = np.zeros((rows, cols), dtype=int)
    for j in range(cols):
        for i in range(j, rows+j):
            B[i-j][j] = A[i][j]
            
    return B

def main():
    M = 4
    K = 4
    N = 4

    # check systolic array's output matrix :)
    golden_act = read_golden('bin/output_golden.hex', M, N)
    output_act = read_output_mem('bin/output_mem.hex', M, N)
    print(stagger_to_matrix(output_act, M, N))
    print(golden_act)

    if np.array_equal(stagger_to_matrix(output_act, M, N), golden_act):
        print('====================')
        print('====== PASSED ======')
        print('====================')
    else:
        print('====================')
        print('====== FAILED ======')
        print('====================')

if __name__ == '__main__':
    main()