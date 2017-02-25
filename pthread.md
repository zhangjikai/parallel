# Pthreads 学习笔记

与OpenMP相比，Pthreads的使用相对要复杂一些，需要我们显式的创建、管理、销毁线程，但也正因为如此，我们对于线程有更强的控制，可以更加灵活的使用线程。这里主要记录一下Pthreads的基本使用方法，如果不是十分复杂的使用环境，这些知识应该可以了。本文大部分内容都是参考自 [pthread Tutorial](http://homes.di.unimi.it/~boccignone/GiuseppeBoccignone_webpage/MatDidatSOD2009_files/pthread-Tutorial.pdf)，有兴趣的可以看一下原文。
