# ComfyUI for gfx1151 (Ryzen AI MAX)

Dockerized ComfyUI with PyTorch & flash-attention for gfx1151 (AMD Strix Halo, Ryzen AI Max+ 395),
relying on AMD's pre-built and pre-configured environment (no custom wheels).

Versions used:
* ROCm: 7.2
* PyTorch: 2.9.1
* Python: 3.12
* ComfyUI (built-in): v0.15.0

> [!CAUTION]
> This is an _opinionated_ implementation of ignatberesnev's comfyui-gfx1151 build. There are key differences:
> * We don't use the docker image registry. I'm a docker-compose girlie, and the local build is just fine for my purposes.
> * API nodes are disabled.  Local only, baby.
> * we use a custom comfyui_frontend with no sentry metrics or telemetrics. Allegedly the telemetrics might only be for cloud, but IDK, no phoning home here! As a result, the dockerfile build will take 8GB of RAM, but if you don't have that, IDK why you're running ComfyUI.
> * We have a whole bunch of plugins. Don't like them? Take them out of your dockerfile, or add your own. DO NOT install plugins vis comfyui-manager, you will lose them on container restart. 
> * We keep most of the comfyui code in the ephemeral container storage, and only expose the volumes I use.

## Get started now

Clone this repo, and run `docker compose up -d`

ComfyUI will be available at http://localhost:8188.

The starter templates should generate images without any issues.

Once you've verified that it works, feel free to use this repository as the foundation for your own setup or workflow.

#### Parameters

Both options have the same pre-configured parameters, which are:

* Allocate 8GB of shared memory (`shm_size`) for internal PyTorch / ComfyUI shenanigans, this should be plenty, 
  feel free to lower it. This should NOT be > than available RAM. This is NOT allocating VRAM.
* Mount `./ComfyUI` for the root of [ComfyUI](https://github.com/comfyanonymous/ComfyUI). If the directory is empty 
  when the container starts, it will copy a pre-cloned (baked in) version of ComfyUI. If it's not empty, it will be 
  used to run ComfyUI located in it. You can update this directory manually to use newer version of ComfyUI without 
  having to re-download the image
* Expose port `8188` for ComfyUI
* Add video + rendering devices and groups. While this just works on Arch, it might require some pre-requisite steps 
  on Ubuntu, I haven't checked.

There are a couple of scripts that can check that both PyTorch and flash-attention work, you can find them below.

#### Updating ComfyUI / dependencies

Update `COMFYUI_REF: v0.15.0` to the version number you're targeting. Then:

```
docker compose build --no-cache comfyui && docker compose up -d comfyui
```

## What's inside / how to replicate

This image is based on AMD's [rocm/pytorch](https://hub.docker.com/r/rocm/pytorch) image that has Ubuntu 24.04, 
ROCm 7.2, Python 3.12 and PyTorch 2.9.1, in which everything is configured to work together and it just works.
You can find out more about this image in 
[AMD's ROCm documentation](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-pytorch.html#use-docker-image-with-pre-installed-pytorch).

There are only two missing pieces which this image adds: [flash-attention](https://github.com/ROCm/flash-attention/) 
and, well, ComfyUI.

There's nothing specific about the ComfyUI installation, you can actually bring your own, it should work.

**flash-attention**, however, "doesn't work" out of the box if you run AMD's image. I'm saying "doesn't work" because, 
as far as I understand, it doesn't have the frontend for it (the APIs), but it does have the backend: **Triton**. 
So flash-attention can be "installed" with a special env variable `FLASH_ATTENTION_TRITON_AMD_ENABLE`, which makes 
ComfyUI and other tools using flash-attention think that flash-attention is installed and works (even though it's 
triton under the hood, which is actually doing the job). You can see the lines that install it in 
[Dockerfile](Dockerfile), and if you try to do it yourself, you'll notice that it executes very fast 
(because flash-attention isn't actually built in full).

It's worth noting that flash-attention is cloned from a specific branch `main_perf` -- I'm not sure why exactly, 
I haven't checked, but I assume it's because it has (stable?) support for Triton which is not yet in the main branch, 
see [this issue](https://github.com/ROCm/flash-attention/issues/27). I basically copy-pasted this part from other
installations ([vLLM](https://community.frame.work/t/compiling-vllm-from-source-on-strix-halo/77241) and repos by 
[kyuz0](https://github.com/kyuz0)), so I hope they know what they're doing :D

In [scripts](scripts) there are two scripts that can check if PyTorch and flash-attention work as expected and utilize 
the iGPU. I used these when looking for a solution, they proved to be helpful, so I'm adding them to the image in case 
something breaks or doesn't work as expected, maybe they'll help debug the problem or something.

With that knowledge, you should be able to take [Dockerfile](Dockerfile) and build an image yourself.

If any of this makes more sense to you than it does to me and you know how to improve something or can add a helpful 
comment with additional context, please do!