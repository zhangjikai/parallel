# MIC HelloWorld
<!-- toc -->
## 什么是MIC
以下摘自"MIC高性能编程指南"
>通常提及MIC系列, 会提及以下几个名词: MIC(Many Integrated Core), Knights系列(如Knights Corner. KNC), Intel<sup>®</sup> Xeon Phi<sup>TM</sup>(官方中文译名:英特尔<sup>® </sup>至强融核<sup>TM</sup>). MIC作为这个系列的架构名称, 类似于CPU, 是对采用这种架构的产品的总称. Knights 系列, 是Intel公司推出的MIC产品的研发代号, 类似于Ivy Bridge, 是内部研发人员对某一代产品的命名,不用于商业用途, 例如第一代正式产品锁采用的,就是Knights Corner架构. 提到具体KNx的架构, 与MIC架构相比, 可以看做是面向对象中父类与子类的关系, MIC架构是父类, 而KNx则是子类.  Intel<sup>®</sup> Xeon Phi<sup>TM</sup>则是产品线的总称, 类似于Pentium、 Xeon等产品系列, Intel<sup>®</sup> Xeon Phi<sup>TM</sup> 是Intel公司推出的基于MIC架构的高性能计算协处理器卡的系列产品名称.  

<!-- more -->
## 运行模式
MIC卡本身自带了一个简化的linux系统, 因此在安装了MIC卡的系统中, MIC既可以和CPU协同工作(使用offload), 也可以独立工作(native模式), 我们这里主要使用的是MIC和CPU协同工作的模式.  

## HelloWorld
为了能够直观的看出我们的程序是在MIC端运行的, 首先介绍一个宏`__MIC__`, 这个宏只有在MIC上运行时才有效, 在CPU端运行是没有该宏的定义的. 下面是
Hello World代码:
```c
#include <stdio.h>

__attribute__ (( target (mic))) void say_hello() {
    //如果有__MIC__的宏定义, 证明是在MIC端运行的
    #ifdef __MIC__
        printf("Hello from MIC\n");
    #else
        printf("Hello from CPU\n");
    #endif
}

int main() {
    #pragma offload target(mic)
    say_hello();
}
```
使用下面的命令进行编译
```bash
icc -o helloworld helloworld.c
```
然后执行helloworld会打印`Hello from MIC`, 如果将'#pragma offload target(mic)' 注释掉, 就会打印出`Hello from CPU`.

## offload(分载)
offload(分载)大概就是说程序在cpu上运行时, 会将一部分的工作交给mic去做, mic做完之后将结果再传递回来.下面是高性能编程指南中中关于分载的定义:
> 分载是指设计的程序运行在处理器上, 同时将部分工作负载分载到一个或多个协处理器上.

因为主处理器和协处理器之间不能共享常规的系统内存, 所以需要大量的分载控制与功能, 因此导致数据在主处理器和协处理器之间需要往复传递. 分载分为两种模式:非共享内存模式和共享虚拟内存模式.
### 非共享内存模式
非共享内存模式使用#pramga预编译指令, 使用方式为`#pragma offload target(mic)` , 上面的HelloWorld就使用了这种模式. 在这种模式下将cpu和mic的内存看作两块独立的内存(实际上也是这样), 数据在这两块内存之间根据需求相互传输. 我们可以指定将哪些数据传输到mic上, 以及将哪些数据传回cpu. 这种模式适合处理扁平的数据结构(flat structure-scalars, arrays, and structs that can be copied from one variable to another using a simple memcpy). 该模式的性能高于共享内存模式.

### 共享虚拟内存模式
共享虚拟内存(shared Virtual Memory) 模式默认集成到Intel Cilk Plus中, 在C/C++编程中使用`_Cilk_shared`和`_Cilk_offload`关键字. 共享虚拟内存不支持Fortran语言.在这种模式下, 变量通过`_Cilk_shared` 关键字在CPU和MIC之间共享, 所共享的动态内存必须通过特定的函数分配:`_Offload_shared_malloc`, `_Offload_shared_aligned_malloc`, `_Offload_shared_free`, `_Offload_shared_aligned_free`. 此模式适用于处理复杂的数据结构,比如链表, 树等. 该模式性能相对较差, 但是为编程提供了方便.
