# токама́к

[![Build Status](https://travis-ci.org/MikeInnes/Tokamak.jl.svg?branch=master)](https://travis-ci.org/MikeInnes/tokamak)

Tokamak is an optimising compiler for index-style array expressions. It's main reason for existence is that I'm too lazy to write a several-hundred-line CUDA kernel for every op I need (matmul, softmax etc) – with Tokamak I can describe them in one line and compile them to fast CPU and GPU kernels. Possible future directions:

* Smarter tiling and other locality optimisations
* Emit BLAS-equivalent kernels without special cases
* Compile larger programs (e.g. entire ML models) to GPUs
* Optimise distributed cluster computation, e.g. JuliaDB

Take a couple of familiar examples:

```julia
@tk function add(A, B)
  C[i] = A[i] + B[i]
end

@tk sum(xs) = reduce(+, 0, xs)

@tk function matmul(A, B)
  C[i, j] = sum([k] -> A[i,k]*B[k,j])
end
```

This is extremely close to traditional mathematical notation. Under the hood, we view arrays as being functions of their indices (hence the "anonymous array" syntax `[...] -> ...`). If a Tokamak function returns an array, the generated code will evaluate that array at every point.

```julia
julia> cpu(add) |> prettify
function (out, goat, mink)
  for elephant = 1:size(goat, 1)
    out[elephant] = goat[elephant] + mink[elephant]
  end
  return out
end
```

Tokamak infers shapes from the description:

```julia
julia> infer(add)
(m) → (m) → (m)

julia> infer(matmul)
(m, n) → (n, o) → (m, o)
```

Functions can return scalars as well, for example (using a short form syntax):

```julia
julia> @tk diag(A)[i] = A[i,i]
julia> @tk trace(A) = sum(diag(A))
julia> infer(trace)
(m, m) → ()

julia> cpu(trace) |> prettify
function (anteater,)
  let
    sum = 0
    for gaur = 1:size(anteater, 1)
      sum += anteater[gaur, gaur]
    end
    sum
  end
end
```

Notice that we do not construct the `diag` array. This applies equally well to more complex examples:

```julia
julia> @tk tracemul(A,B) = sum(diag(mul(A,B)))

julia> infer(tracemul)
(m, n) → (n, m) → ()

julia> cpu(tracemul) |> prettify
function (duck, leopard)
  let
    sum = 0.0
    for goosander = 1:size(duck, 1)
      sum += let
              sum = 0.0
              for horse = 1:size(duck, 2)
                  sum += duck[goosander, horse] * leopard[horse, goosander]
              end
              sum
          end
    end
    sum
  end
end
```

Crucially, we only calculate the elements of the matrix multiply that we actually need. Despite the relative naivety of the generated code, this is enough to get a solid 10x speedup over the equivalent BLAS.

## GPU Example

Tokamak supports (extremely early stage, totally untested) GPU compilation. Consider defining enough to do a single layer of an mlp: `tanh(x*W + b)`.

```julia
@tk add(a, b)[i, j] = a[i, j] + b[i, j]
@tk mul(A,B)[i,j] = sum([k] -> A[i,k]*B[k,j])
@tk act(a)[i, j] = tanh(a[i, j])

@tk net(W, b, x) = act(add(mul(x, W), b))

infer(net) # (m, n) → (o, n) → (o, m) → (o, n)

gpu(net) |> prettify
function (out, waterbuffalo, sealion, otter)
  (gnat, oyster) = ((blockIdx().x - 1) * blockDim().x + threadIdx().x,
                    (blockIdx().y - 1) * blockDim().y + threadIdx().y)
  out[gnat, oyster] = tanh(begin
    snail = 0
    for pig = 1:size(otter, 2)
      snail = snail + otter[gnat, pig] * waterbuffalo[pig, oyster]
    end
    snail
  end + sealion[gnat, oyster])
  return out
end
```

So here we have a fused kernel which does the entire operation in one pass.

See the [tests](/test/runtests.jl) for more detailed examples.
