# Offload 模式



这种方式对应于我们前面所说的非共享内存模型，这里记录一下它的基本用法
<!-- toc -->
## 定义MIC使用的函数和变量
如果是局部变量, 那么我们不需要做额外的工作, 如果全局变量或者函数, 要在mic上使用它们, 则需要使用下面的方式声明或者定义:
```bash
__declspec( target (mic)) function-declaration
__declspec( target (mic)) variable-declaration
__attribute__ (( target (mic))) function-declaration
__attribute__ (( target (mic))) variable-declaration
```
其中`__declspec`可以用于windows或者linux系统, 而`_attribute__`只能用于linux.  
<!-- more -->
下面使用示例:
```c
#include <stdio.h>

#define __ONMIC__ __attribute__((target(mic)))

__ONMIC__ int i;

__ONMIC__ void f(int n) {
    printf("n*n is %d\n", n*n);
}

int main() {

    #pragma offload target(mic)
    {
        i = 100;
        f(i);
    }

    printf("i is %d\n", i);
}
```
## 数据传输
虽然在host(主机端, 例如CPU)和targets(设备端, 例如MIC卡)端使用的指令集是相似的, 但是它们并不共享同一个系统内存, 这也就意味着在`#pragma`代码块中用到的变量必须同时存在
于host和target上, 为了确保这样, pragma使用特定的说明符(Specifiers)[`in`, `out`, `inout`]来指定在host和target之间复制的变量.
* in: 指定一个变量从host端复制到target端(作为target的输入), 但是不从target端复制回host端
* out: 指定一个变量从target端复制回host端(作为target的输出), 但是不从host段复制到target端
* inout: 指定一个变量即从host端复制到target端, 也从target段复制回host端(即是输入又是输出).

在没有显示的调用说明符, 那么默认inout. 下面是一个示例
```c
#include <stdio.h>

int main() {
    int inVar = 10;
    int outVar = 20;
    int inoutVar = 30;

    #pragma offload target(mic) in(inVar) out(outVar)
    {
        printf("inVar in MIC is %d\n", inVar);
        printf("outVar in MIC is %d\n", outVar);
        // 这里用到了inoutVar, 但是offload时并没有指定它的说明符, 则用默认的inout
        printf("inoutVar in MIC is %d\n", inoutVar);

        inVar = 100;
        outVar = 200;
        inoutVar = 300;
    }

    printf("inVar in CPU is %d\n", inVar);
    printf("outVar in CPU is %d\n", outVar);
    printf("inoutVar in CPU is %d\n", inoutVar);
}
```
输出结果为:
```bash
inVar in CPU is 10
outVar in CPU is 200
inoutVar in CPU is 300
inVar in MIC is 10
outVar in MIC is 0
inoutVar in MIC is 30
```
从上面可以看出inVar的值传到了MIC上, 但是在MIC上修改后并没有传回CPU, CPU中outVar的没有传递到MIC上, 但是MIC上outVar的值却是传回到了CPU上,而inoutVar的值即传递到了MIC,也从MIC上传了回来. 同时我们还可以看到, 先打印的是in CPU, 又打印的in MIC, 这是因为在target端(比如MIC卡)输出时, 因为PCI-E设备(MIC卡是插在PCI-E插槽上的) 无法直接访问显示器, 所以必须经过CPU中转. 虽然各家厂商实现方式不尽相同, 但总免不了使用卡上的内存进行缓冲, 之后交换到host端内存中, 再进行输出, 这样就会有一定的延迟, 因此一般target上的输出要慢于host端的输出.
