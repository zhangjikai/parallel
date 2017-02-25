# HelloWord

<!-- toc -->

## 安装 MPI 运行环境
[Installing MPICH2 on a Single Machine](http://mpitutorial.com/tutorials/installing-mpich2/)  

去 [MPICH2 官网](http://www.mpich.org/downloads/)下载源码包，然后安装
```Bash
tar -xzf mpich-3.2.tar.gz
cd mpich-3.2
./configure --disable-fortran CC=gcc CXX=g++
make
sudo mark install
```
安装了 Intel 编译器的可以使用 `mpiicc` 和 `mpiicpc`

## HelloWorld
```c
#include <mpi.h>
#include <stdio.h>

int main(int argc, char** argv) {
    // Initialize the MPI environment
    MPI_Init(NULL, NULL);

    // Get the number of processes
    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    // Get the rank of the process
    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    // Get the name of the processor
    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    MPI_Get_processor_name(processor_name, &name_len);

    // Print off a hello world message
    printf("Hello world from processor %s, rank %d"
           " out of %d processors\n",
           processor_name, world_rank, world_size);

    // Finalize the MPI environment.
    MPI_Finalize();
}
```
## 编译
```bash
mpicc -o helloworld helloworld.c
```
## 运行
```bash
mpiexec ./helloworld
// 或者
mpirun ./helloworld
```
`mpirun` 等同于 `mpiexec`

 mpirun 命令
 ```
 mpirun -n <# of processes> -ppn <# of processes per node> -f <hostfile> ./myprog
 ```
* `-n` - sets the number of MPI processes to launch; if the option is not specified, the process manager pulls the host list from a job scheduler, or uses the number of cores on the machine.
* `-ppn` - sets the number of processes to launch on each node; if the option is not specified, processes are assigned to the physical cores on the first node; if the number of cores is exceeded, the next node is used.
* `-f` - specifies the path to the host file listing the cluster nodes; alternatively, you can use the -hosts option to specify a comma-separated list of nodes; if hosts are not specified, the local node is used.

如果需要在多个节点上运行运行，可以参考 [无需超级用户mpi多机执行](http://blog.csdn.net/bendanban/article/details/40710217)
