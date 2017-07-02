using Tokamak: @tk, infer, cpu
using Base.Test

@tk diag(A)[i] = A[i,i]
@tk trans(A)[i,j] = A[j,i]
@tk add(A,B)[i] = A[i] + B[i]
@tk sum(xs) = reduce(+, 0, [i] -> xs[i])
@tk mul(A,B)[i,j] = reduce(+, 0, [k] -> A[i,k]*B[k,j])

@test string(infer(diag)) == "(m, m) → (m)"
@test string(infer(trans)) == "(m, n) → (n, m)"
@test string(infer(add)) == "(m) → (m) → (m)"
@test string(infer(sum)) == "(m) → ()"
@test string(infer(mul)) == "(m, n) → (n, o) → (m, o)"

diagf = eval(cpu(diag))
@test diagf(zeros(3), reshape(1:9, (3, 3))) == [1,5,9]

sumf = eval(cpu(sum))
@test sumf([1,2,3]) == Base.sum([1,2,3])

addf = eval(cpu(add))
@test addf(zeros(3), [1,2,3],[4,5,6]) == [5,7,9]

mulf = eval(cpu(mul))
A, B = rand(5,5), rand(5,5)
@test mulf(zeros(5,5), A, B) ≈ A*B
