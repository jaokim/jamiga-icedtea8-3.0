#!/usr/bin/perl

use strict;
use warnings;

use Config;
# For log file.
use File::Basename;
use File::Path;
my $log_file;
my $logfile_name;

# For parsing options.
use Getopt::Std;
$Getopt::Std::OUTPUT_HELP_VERSION = 1;
# sub main::HELP_MESSAGE defined below.
our($opt_B, $opt_A, $opt_o, $opt_a, $opt_S, $opt_J, $opt_p, $opt_j);

# Gigantic nested array.
# Each element in outer array should be of the form:
#    ["<NAME>", "<PRINTARG>", "<TARGET>"]
# NAME is the name of a probe alias.
# PRINTARG is a (quoted, escaped) format string along with additional variable
# arguments, separated by commas, that will be inserted as the arguments to
# a printf() call in a systemtap script.
# TARGET is the expected output of the probe firing in a test, or (where exact
# output is not known) a matching regex.
my @probestrings = (["hotspot.gc_begin", "\"%s\\n\",name", "^gc_begin\$"],
    ["hotspot.gc_end", "\"%s\\n\",name", "^gc_end\$"],
    ["hotspot.mem_pool_gc_begin", "\"%s\\n\",name", "^mem_pool_gc_begin\$"],
    ["hotspot.mem_pool_gc_end", "\"%s\\n\",name", "^mem_pool_gc_end\$"],
    ["hotspot.object_alloc", "\"%stid=%dclass=%s\\n\",name,thread_id,class", "^object_alloctid=1class=staptest/SystemtapTester\$"],
    ["hotspot.vm_init_begin", "\"%s\\n\",name", "^vm_init_begin\$"],
    ["hotspot.vm_init_end", "\"%s\\n\",name", "^vm_init_end\$"],
    ["hotspot.vm_shutdown", "\"%s\\n\",name", "^vm_shutdown\$"],
    ["hotspot.thread_start", "\"%sname=%stid=%dd=%d\\n\",name,thread_name,id,is_daemon", "^thread_startname=Thread-0tid=[0-9]\\+d=0\$"],
    ["hotspot.thread_stop", "\"%sname=%stid=%dd=%d\\n\",name,thread_name,id,is_daemon", "^thread_stopname=Thread-0tid=[0-9]\\+d=0\$"],
    ["hotspot.class_loaded", "\"%sclass=%ssh=%d\\n\",name,class,is_shared", "class_loadedclass=staptest/ClassUnloadedProbeTestersh=0"],
    ["hotspot.class_unloaded", "\"%sclass=%ssh=%d\\n\",name,class,is_shared", "class_unloadedclass=staptest/ClassUnloadedProbeTestersh=0"],
    ["hotspot.method_compile_begin", "\"%sclass=%smethod=%ssig=%s\\n\",name,class,method,sig", "method_compile_beginclass=staptest/SystemtapTestermethod=allocateForNoReasonsig=(I)Ljava/lang/String;"],
    ["hotspot.method_compile_end", "\"%sclass=%smethod=%ssig=%s\\n\",name,class,method,sig", "method_compile_endclass=staptest/SystemtapTestermethod=allocateForNoReasonsig=(I)Ljava/lang/String;"],
    ["hotspot.monitor_wait", "\"%sclass=%sto=%d\\n\",name,class,timeout", "monitor_waitclass=staptest/TestingRunnerto=0"],
    ["hotspot.monitor_waited", "\"%sclass=%s\\n\",name,class", "monitor_waitedclass=staptest/TestingRunner"],
    ["hotspot.monitor_notify", "\"%sclass=%s\\n\",name,class", "monitor_notifyclass=staptest/TestingRunner"],
    ["hotspot.monitor_notifyAll", "\"%sclass=%s\\n\",name,class", "monitor_notifyAllclass=staptest/TestingRunner"],
    ["hotspot.monitor_contended_enter", "\"%sclass=%s\\n\",name,class", "monitor_contended_enterclass=java/lang/Class"],
    ["hotspot.monitor_contended_entered", "\"%sclass=%s\\n\",name,class", "monitor_contended_enteredclass=java/lang/Class"],
    ["hotspot.monitor_contended_exit", "\"%sclass=%s\\n\",name,class", "monitor_contended_exitclass=java/lang/Class"],
    ["hotspot.method_entry", "\"%sclass=%smethod=%ssig=%s\\n\",name,class,method,sig", "method_entryclass=staptest/SystemtapTestermethod=<init>sig=()V"],
    ["hotspot.method_return", "\"%sclass=%smethod=%ssig=%s\\n\",name,class,method,sig", "method_returnclass=staptest/SystemtapTestermethod=<init>sig=()V"],
    ["hotspot.compiled_method_load", "\"%sclass=%smethod=%ssig=%s\\n\",name,class,method,sig", "compiled_method_loadclass=staptest/SystemtapTestermethod=allocateForNoReasonsig=(I)Ljava/lang/String;"],
    ["hotspot.compiled_method_unload", "\"%sclass=%smethod=%ssig=%s\\n\",name,class,method,sig", "compiled_method_unloadclass=staptest/ClassUnloadedProbeTestermethod=setFieldsig=(I)V"],
    ["hotspot.jni.AllocObject", "\"%s\\n\",name", "AllocObject"],
    ["hotspot.jni.AllocObject.return", "\"%sret=%d\\n\",name,ret", "AllocObjectret=[^0]"],
    ["hotspot.jni.AttachCurrentThreadAsDaemon", "\"%s\\n\",name", "AttachCurrentThreadAsDaemon"],
    ["hotspot.jni.AttachCurrentThreadAsDaemon.return", "\"%sret=%d\\n\",name,ret", "AttachCurrentThreadAsDaemonret=0"],
    ["hotspot.jni.AttachCurrentThread", "\"%s\\n\",name", "AttachCurrentThread"],
    ["hotspot.jni.AttachCurrentThread.return", "\"%sret=%d\\n\",name,ret", "AttachCurrentThreadret=0"],
    ["hotspot.jni.CallBooleanMethodA", "\"%s\\n\",name", "CallBooleanMethodA"],
    ["hotspot.jni.CallBooleanMethodA.return", "\"%sret=%d\\n\",name,ret", "CallBooleanMethodAret=1"],
    ["hotspot.jni.CallBooleanMethod", "\"%s\\n\",name", "CallBooleanMethod"],
    ["hotspot.jni.CallBooleanMethod.return", "\"%sret=%d\\n\",name,ret", "CallBooleanMethodret=1"],
    ["hotspot.jni.CallBooleanMethodV", "\"%s\\n\",name", "CallBooleanMethodV"],
    ["hotspot.jni.CallBooleanMethodV.return", "\"%sret=%d\\n\",name,ret", "CallBooleanMethodVret=1"],
    ["hotspot.jni.CallByteMethodA", "\"%s\\n\",name", "CallByteMethodA"],
    ["hotspot.jni.CallByteMethodA.return", "\"%sret=%d\\n\",name,ret", "CallByteMethodAret=0"],
    ["hotspot.jni.CallByteMethod", "\"%s\\n\",name", "CallByteMethod"],
    ["hotspot.jni.CallByteMethod.return", "\"%sret=%d\\n\",name,ret", "CallByteMethodret=0"],
    ["hotspot.jni.CallByteMethodV", "\"%s\\n\",name", "CallByteMethodV"],
    ["hotspot.jni.CallByteMethodV.return", "\"%sret=%d\\n\",name,ret", "CallByteMethodVret=0"],
    ["hotspot.jni.CallCharMethodA", "\"%s\\n\",name", "CallCharMethodA"],
    ["hotspot.jni.CallCharMethodA.return", "\"%sret=%d\\n\",name,ret", "CallCharMethodAret=97"],
    ["hotspot.jni.CallCharMethod", "\"%s\\n\",name", "CallCharMethod"],
    ["hotspot.jni.CallCharMethod.return", "\"%sret=%d\\n\",name,ret", "CallCharMethodret=97"],
    ["hotspot.jni.CallCharMethodV", "\"%s\\n\",name", "CallCharMethodV"],
    ["hotspot.jni.CallCharMethodV.return", "\"%sret=%d\\n\",name,ret", "CallCharMethodVret=97"],
    ["hotspot.jni.CallDoubleMethodA", "\"%s\\n\",name", "CallDoubleMethodA"],
    ["hotspot.jni.CallDoubleMethodA.return", "\"%s\\n\",name", "CallDoubleMethodA"],
    ["hotspot.jni.CallDoubleMethod", "\"%s\\n\",name", "CallDoubleMethod"],
    ["hotspot.jni.CallDoubleMethod.return", "\"%s\\n\",name", "CallDoubleMethod"],
    ["hotspot.jni.CallDoubleMethodV", "\"%s\\n\",name", "CallDoubleMethodV"],
    ["hotspot.jni.CallDoubleMethodV.return", "\"%s\\n\",name", "CallDoubleMethodV"],
    ["hotspot.jni.CallFloatMethodA", "\"%s\\n\",name", "CallFloatMethodA"],
    ["hotspot.jni.CallFloatMethodA.return", "\"%s\\n\",name", "CallFloatMethodA"],
    ["hotspot.jni.CallFloatMethod", "\"%s\\n\",name", "CallFloatMethod"],
    ["hotspot.jni.CallFloatMethod.return", "\"%s\\n\",name", "CallFloatMethod"],
    ["hotspot.jni.CallFloatMethodV", "\"%s\\n\",name", "CallFloatMethodV"],
    ["hotspot.jni.CallFloatMethodV.return", "\"%s\\n\",name", "CallFloatMethodV"],
    ["hotspot.jni.CallIntMethodA", "\"%s\\n\",name", "CallIntMethodA"],
    ["hotspot.jni.CallIntMethodA.return", "\"%sret=%d\\n\",name,ret", "CallIntMethodAret=4"],
    ["hotspot.jni.CallIntMethod", "\"%s\\n\",name", "CallIntMethod"],
    ["hotspot.jni.CallIntMethod.return", "\"%sret=%d\\n\",name,ret", "CallIntMethodret=4"],
    ["hotspot.jni.CallIntMethodV", "\"%s\\n\",name", "CallIntMethodV"],
    ["hotspot.jni.CallIntMethodV.return", "\"%sret=%d\\n\",name,ret", "CallIntMethodVret=4"],
    ["hotspot.jni.CallLongMethodA", "\"%s\\n\",name", "CallLongMethodA"],
    ["hotspot.jni.CallLongMethodA.return", "\"%sret=%d\\n\",name,ret", "CallLongMethodAret=8"],
    ["hotspot.jni.CallLongMethod", "\"%s\\n\",name", "CallLongMethod"],
    ["hotspot.jni.CallLongMethod.return", "\"%sret=%d\\n\",name,ret", "CallLongMethodret=8"],
    ["hotspot.jni.CallLongMethodV", "\"%s\\n\",name", "CallLongMethodV"],
    ["hotspot.jni.CallLongMethodV.return", "\"%sret=%d\\n\",name,ret", "CallLongMethodVret=8"],
    ["hotspot.jni.CallObjectMethodA", "\"%s\\n\",name", "CallObjectMethodA"],
    ["hotspot.jni.CallObjectMethodA.return", "\"%s\\n\",name", "CallObjectMethodA"],
    ["hotspot.jni.CallObjectMethod", "\"%s\\n\",name", "CallObjectMethod"],
    ["hotspot.jni.CallObjectMethod.return", "\"%s\\n\",name", "CallObjectMethod"],
    ["hotspot.jni.CallObjectMethodV", "\"%s\\n\",name", "CallObjectMethodV"],
    ["hotspot.jni.CallObjectMethodV.return", "\"%s\\n\",name", "CallObjectMethodV"],
    ["hotspot.jni.CallShortMethodA", "\"%s\\n\",name", "CallShortMethodA"],
    ["hotspot.jni.CallShortMethodA.return", "\"%sret=%d\\n\",name,ret", "CallShortMethodAret=2"],
    ["hotspot.jni.CallShortMethod", "\"%s\\n\",name", "CallShortMethod"],
    ["hotspot.jni.CallShortMethod.return", "\"%sret=%d\\n\",name,ret", "CallShortMethodret=2"],
    ["hotspot.jni.CallShortMethodV", "\"%s\\n\",name", "CallShortMethodV"],
    ["hotspot.jni.CallShortMethodV.return", "\"%sret=%d\\n\",name,ret", "CallShortMethodVret=2"],
    ["hotspot.jni.CallVoidMethodA", "\"%s\\n\",name", "CallVoidMethodA"],
    ["hotspot.jni.CallVoidMethodA.return", "\"%s\\n\",name", "CallVoidMethodA"],
    ["hotspot.jni.CallVoidMethod", "\"%s\\n\",name", "CallVoidMethod"],
    ["hotspot.jni.CallVoidMethod.return", "\"%s\\n\",name", "CallVoidMethod"],
    ["hotspot.jni.CallVoidMethodV", "\"%s\\n\",name", "CallVoidMethodV"],
    ["hotspot.jni.CallVoidMethodV.return", "\"%s\\n\",name", "CallVoidMethodV"],
    ["hotspot.jni.CallNonvirtualBooleanMethodA", "\"%s\\n\",name", "CallNonvirtualBooleanMethodA"],
    ["hotspot.jni.CallNonvirtualBooleanMethodA.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualBooleanMethodAret=1"],
    ["hotspot.jni.CallNonvirtualBooleanMethod", "\"%s\\n\",name", "CallNonvirtualBooleanMethod"],
    ["hotspot.jni.CallNonvirtualBooleanMethod.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualBooleanMethodret=1"],
    ["hotspot.jni.CallNonvirtualBooleanMethodV", "\"%s\\n\",name", "CallNonvirtualBooleanMethodV"],
    ["hotspot.jni.CallNonvirtualBooleanMethodV.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualBooleanMethodVret=1"],
    ["hotspot.jni.CallNonvirtualByteMethodA", "\"%s\\n\",name", "CallNonvirtualByteMethodA"],
    ["hotspot.jni.CallNonvirtualByteMethodA.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualByteMethodAret=0"],
    ["hotspot.jni.CallNonvirtualByteMethod", "\"%s\\n\",name", "CallNonvirtualByteMethod"],
    ["hotspot.jni.CallNonvirtualByteMethod.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualByteMethodret=0"],
    ["hotspot.jni.CallNonvirtualByteMethodV", "\"%s\\n\",name", "CallNonvirtualByteMethodV"],
    ["hotspot.jni.CallNonvirtualByteMethodV.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualByteMethodVret=0"],
    ["hotspot.jni.CallNonvirtualCharMethodA", "\"%s\\n\",name", "CallNonvirtualCharMethodA"],
    ["hotspot.jni.CallNonvirtualCharMethodA.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualCharMethodAret=97"],
    ["hotspot.jni.CallNonvirtualCharMethod", "\"%s\\n\",name", "CallNonvirtualCharMethod"],
    ["hotspot.jni.CallNonvirtualCharMethod.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualCharMethodret=97"],
    ["hotspot.jni.CallNonvirtualCharMethodV", "\"%s\\n\",name", "CallNonvirtualCharMethodV"],
    ["hotspot.jni.CallNonvirtualCharMethodV.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualCharMethodVret=97"],
    ["hotspot.jni.CallNonvirtualDoubleMethodA", "\"%s\\n\",name", "CallNonvirtualDoubleMethodA"],
    ["hotspot.jni.CallNonvirtualDoubleMethodA.return", "\"%s\\n\",name", "CallNonvirtualDoubleMethodA"],
    ["hotspot.jni.CallNonvirtualDoubleMethod", "\"%s\\n\",name", "CallNonvirtualDoubleMethod"],
    ["hotspot.jni.CallNonvirtualDoubleMethod.return", "\"%s\\n\",name", "CallNonvirtualDoubleMethod"],
    ["hotspot.jni.CallNonvirtualDoubleMethodV", "\"%s\\n\",name", "CallNonvirtualDoubleMethodV"],
    ["hotspot.jni.CallNonvirtualDoubleMethodV.return", "\"%s\\n\",name", "CallNonvirtualDoubleMethodV"],
    ["hotspot.jni.CallNonvirtualFloatMethodA", "\"%s\\n\",name", "CallNonvirtualFloatMethodA"],
    ["hotspot.jni.CallNonvirtualFloatMethodA.return", "\"%s\\n\",name", "CallNonvirtualFloatMethodA"],
    ["hotspot.jni.CallNonvirtualFloatMethod", "\"%s\\n\",name", "CallNonvirtualFloatMethod"],
    ["hotspot.jni.CallNonvirtualFloatMethod.return", "\"%s\\n\",name", "CallNonvirtualFloatMethod"],
    ["hotspot.jni.CallNonvirtualFloatMethodV", "\"%s\\n\",name", "CallNonvirtualFloatMethodV"],
    ["hotspot.jni.CallNonvirtualFloatMethodV.return", "\"%s\\n\",name", "CallNonvirtualFloatMethodV"],
    ["hotspot.jni.CallNonvirtualIntMethodA", "\"%s\\n\",name", "CallNonvirtualIntMethodA"],
    ["hotspot.jni.CallNonvirtualIntMethodA.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualIntMethodAret=4"],
    ["hotspot.jni.CallNonvirtualIntMethod", "\"%s\\n\",name", "CallNonvirtualIntMethod"],
    ["hotspot.jni.CallNonvirtualIntMethod.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualIntMethodret=4"],
    ["hotspot.jni.CallNonvirtualIntMethodV", "\"%s\\n\",name", "CallNonvirtualIntMethodV"],
    ["hotspot.jni.CallNonvirtualIntMethodV.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualIntMethodVret=4"],
    ["hotspot.jni.CallNonvirtualLongMethodA", "\"%s\\n\",name", "CallNonvirtualLongMethodA"],
    ["hotspot.jni.CallNonvirtualLongMethodA.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualLongMethodAret=8"],
    ["hotspot.jni.CallNonvirtualLongMethod", "\"%s\\n\",name", "CallNonvirtualLongMethod"],
    ["hotspot.jni.CallNonvirtualLongMethod.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualLongMethodret=8"],
    ["hotspot.jni.CallNonvirtualLongMethodV", "\"%s\\n\",name", "CallNonvirtualLongMethodV"],
    ["hotspot.jni.CallNonvirtualLongMethodV.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualLongMethodVret=8"],
    ["hotspot.jni.CallNonvirtualObjectMethodA", "\"%s\\n\",name", "CallNonvirtualObjectMethodA"],
    ["hotspot.jni.CallNonvirtualObjectMethodA.return", "\"%s\\n\",name", "CallNonvirtualObjectMethodA"],
    ["hotspot.jni.CallNonvirtualObjectMethod", "\"%s\\n\",name", "CallNonvirtualObjectMethod"],
    ["hotspot.jni.CallNonvirtualObjectMethod.return", "\"%s\\n\",name", "CallNonvirtualObjectMethod"],
    ["hotspot.jni.CallNonvirtualObjectMethodV", "\"%s\\n\",name", "CallNonvirtualObjectMethodV"],
    ["hotspot.jni.CallNonvirtualObjectMethodV.return", "\"%s\\n\",name", "CallNonvirtualObjectMethodV"],
    ["hotspot.jni.CallNonvirtualShortMethodA", "\"%s\\n\",name", "CallNonvirtualShortMethodA"],
    ["hotspot.jni.CallNonvirtualShortMethodA.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualShortMethodAret=2"],
    ["hotspot.jni.CallNonvirtualShortMethod", "\"%s\\n\",name", "CallNonvirtualShortMethod"],
    ["hotspot.jni.CallNonvirtualShortMethod.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualShortMethodret=2"],
    ["hotspot.jni.CallNonvirtualShortMethodV", "\"%s\\n\",name", "CallNonvirtualShortMethodV"],
    ["hotspot.jni.CallNonvirtualShortMethodV.return", "\"%sret=%d\\n\",name,ret", "CallNonvirtualShortMethodVret=2"],
    ["hotspot.jni.CallNonvirtualVoidMethodA", "\"%s\\n\",name", "CallNonvirtualVoidMethodA"],
    ["hotspot.jni.CallNonvirtualVoidMethodA.return", "\"%s\\n\",name", "CallNonvirtualVoidMethodA"],
    ["hotspot.jni.CallNonvirtualVoidMethod", "\"%s\\n\",name", "CallNonvirtualVoidMethod"],
    ["hotspot.jni.CallNonvirtualVoidMethod.return", "\"%s\\n\",name", "CallNonvirtualVoidMethod"],
    ["hotspot.jni.CallNonvirtualVoidMethodV", "\"%s\\n\",name", "CallNonvirtualVoidMethodV"],
    ["hotspot.jni.CallNonvirtualVoidMethodV.return", "\"%s\\n\",name", "CallNonvirtualVoidMethodV"],
    ["hotspot.jni.CallStaticBooleanMethodA", "\"%s\\n\",name", "CallStaticBooleanMethodA"],
    ["hotspot.jni.CallStaticBooleanMethodA.return", "\"%sret=%d\\n\",name,ret", "CallStaticBooleanMethodAret=0"],
    ["hotspot.jni.CallStaticBooleanMethod", "\"%s\\n\",name", "CallStaticBooleanMethod"],
    ["hotspot.jni.CallStaticBooleanMethod.return", "\"%sret=%d\\n\",name,ret", "CallStaticBooleanMethodret=0"],
    ["hotspot.jni.CallStaticBooleanMethodV", "\"%s\\n\",name", "CallStaticBooleanMethodV"],
    ["hotspot.jni.CallStaticBooleanMethodV.return", "\"%sret=%d\\n\",name,ret", "CallStaticBooleanMethodVret=0"],
    ["hotspot.jni.CallStaticByteMethodA", "\"%s\\n\",name", "CallStaticByteMethodA"],
    ["hotspot.jni.CallStaticByteMethodA.return", "\"%sret=%d\\n\",name,ret", "CallStaticByteMethodAret=1"],
    ["hotspot.jni.CallStaticByteMethod", "\"%s\\n\",name", "CallStaticByteMethod"],
    ["hotspot.jni.CallStaticByteMethod.return", "\"%sret=%d\\n\",name,ret", "CallStaticByteMethodret=1"],
    ["hotspot.jni.CallStaticByteMethodV", "\"%s\\n\",name", "CallStaticByteMethodV"],
    ["hotspot.jni.CallStaticByteMethodV.return", "\"%sret=%d\\n\",name,ret", "CallStaticByteMethodVret=1"],
    ["hotspot.jni.CallStaticCharMethodA", "\"%s\\n\",name", "CallStaticCharMethodA"],
    ["hotspot.jni.CallStaticCharMethodA.return", "\"%sret=%d\\n\",name,ret", "CallStaticCharMethodAret=98"],
    ["hotspot.jni.CallStaticCharMethod", "\"%s\\n\",name", "CallStaticCharMethod"],
    ["hotspot.jni.CallStaticCharMethod.return", "\"%sret=%d\\n\",name,ret", "CallStaticCharMethodret=98"],
    ["hotspot.jni.CallStaticCharMethodV", "\"%s\\n\",name", "CallStaticCharMethodV"],
    ["hotspot.jni.CallStaticCharMethodV.return", "\"%sret=%d\\n\",name,ret", "CallStaticCharMethodVret=98"],
    ["hotspot.jni.CallStaticDoubleMethodA", "\"%s\\n\",name", "CallStaticDoubleMethodA"],
    ["hotspot.jni.CallStaticDoubleMethodA.return", "\"%s\\n\",name", "CallStaticDoubleMethodA"],
    ["hotspot.jni.CallStaticDoubleMethod", "\"%s\\n\",name", "CallStaticDoubleMethod"],
    ["hotspot.jni.CallStaticDoubleMethod.return", "\"%s\\n\",name", "CallStaticDoubleMethod"],
    ["hotspot.jni.CallStaticDoubleMethodV", "\"%s\\n\",name", "CallStaticDoubleMethodV"],
    ["hotspot.jni.CallStaticDoubleMethodV.return", "\"%s\\n\",name", "CallStaticDoubleMethodV"],
    ["hotspot.jni.CallStaticFloatMethodA", "\"%s\\n\",name", "CallStaticFloatMethodA"],
    ["hotspot.jni.CallStaticFloatMethodA.return", "\"%s\\n\",name", "CallStaticFloatMethodA"],
    ["hotspot.jni.CallStaticFloatMethod", "\"%s\\n\",name", "CallStaticFloatMethod"],
    ["hotspot.jni.CallStaticFloatMethod.return", "\"%s\\n\",name", "CallStaticFloatMethod"],
    ["hotspot.jni.CallStaticFloatMethodV", "\"%s\\n\",name", "CallStaticFloatMethodV"],
    ["hotspot.jni.CallStaticFloatMethodV.return", "\"%s\\n\",name", "CallStaticFloatMethodV"],
    ["hotspot.jni.CallStaticIntMethodA", "\"%s\\n\",name", "CallStaticIntMethodA"],
    ["hotspot.jni.CallStaticIntMethodA.return", "\"%sret=%d\\n\",name,ret", "CallStaticIntMethodAret=32"],
    ["hotspot.jni.CallStaticIntMethod", "\"%s\\n\",name", "CallStaticIntMethod"],
    ["hotspot.jni.CallStaticIntMethod.return", "\"%sret=%d\\n\",name,ret", "CallStaticIntMethodret=32"],
    ["hotspot.jni.CallStaticIntMethodV", "\"%s\\n\",name", "CallStaticIntMethodV"],
    ["hotspot.jni.CallStaticIntMethodV.return", "\"%sret=%d\\n\",name,ret", "CallStaticIntMethodVret=32"],
    ["hotspot.jni.CallStaticLongMethodA", "\"%s\\n\",name", "CallStaticLongMethodA"],
    ["hotspot.jni.CallStaticLongMethodA.return", "\"%sret=%d\\n\",name,ret", "CallStaticLongMethodAret=64"],
    ["hotspot.jni.CallStaticLongMethod", "\"%s\\n\",name", "CallStaticLongMethod"],
    ["hotspot.jni.CallStaticLongMethod.return", "\"%sret=%d\\n\",name,ret", "CallStaticLongMethodret=64"],
    ["hotspot.jni.CallStaticLongMethodV", "\"%s\\n\",name", "CallStaticLongMethodV"],
    ["hotspot.jni.CallStaticLongMethodV.return", "\"%sret=%d\\n\",name,ret", "CallStaticLongMethodVret=64"],
    ["hotspot.jni.CallStaticObjectMethodA", "\"%s\\n\",name", "CallStaticObjectMethodA"],
    ["hotspot.jni.CallStaticObjectMethodA.return", "\"%s\\n\",name", "CallStaticObjectMethodA"],
    ["hotspot.jni.CallStaticObjectMethod", "\"%s\\n\",name", "CallStaticObjectMethod"],
    ["hotspot.jni.CallStaticObjectMethod.return", "\"%s\\n\",name", "CallStaticObjectMethod"],
    ["hotspot.jni.CallStaticObjectMethodV", "\"%s\\n\",name", "CallStaticObjectMethodV"],
    ["hotspot.jni.CallStaticObjectMethodV.return", "\"%s\\n\",name", "CallStaticObjectMethodV"],
    ["hotspot.jni.CallStaticShortMethodA", "\"%s\\n\",name", "CallStaticShortMethodA"],
    ["hotspot.jni.CallStaticShortMethodA.return", "\"%sret=%d\\n\",name,ret", "CallStaticShortMethodAret=16"],
    ["hotspot.jni.CallStaticShortMethod", "\"%s\\n\",name", "CallStaticShortMethod"],
    ["hotspot.jni.CallStaticShortMethod.return", "\"%sret=%d\\n\",name,ret", "CallStaticShortMethodret=16"],
    ["hotspot.jni.CallStaticShortMethodV", "\"%s\\n\",name", "CallStaticShortMethodV"],
    ["hotspot.jni.CallStaticShortMethodV.return", "\"%sret=%d\\n\",name,ret", "CallStaticShortMethodVret=16"],
    ["hotspot.jni.CallStaticVoidMethodA", "\"%s\\n\",name", "CallStaticVoidMethodA"],
    ["hotspot.jni.CallStaticVoidMethodA.return", "\"%s\\n\",name", "CallStaticVoidMethodA"],
    ["hotspot.jni.CallStaticVoidMethod", "\"%s\\n\",name", "CallStaticVoidMethod"],
    ["hotspot.jni.CallStaticVoidMethod.return", "\"%s\\n\",name", "CallStaticVoidMethod"],
    ["hotspot.jni.CallStaticVoidMethodV", "\"%s\\n\",name", "CallStaticVoidMethodV"],
    ["hotspot.jni.CallStaticVoidMethodV.return", "\"%s\\n\",name", "CallStaticVoidMethodV"],
    ["hotspot.jni.CreateJavaVM", "\"%s\\n\",name", "CreateJavaVM"],
    ["hotspot.jni.CreateJavaVM.return", "\"%sret=%d\\n\",name,ret", "CreateJavaVMret=0"],
    ["hotspot.jni.DefineClass", "\"%sclass=%s\\n\",name,clazz", "DefineClassclass=staptest/JNITestClass"],
    ["hotspot.jni.DefineClass.return", "\"%sret=%d\\n\",name,ret", "DefineClassret=[^0]"],
    ["hotspot.jni.DeleteGlobalRef", "\"%s\\n\",name", "DeleteGlobalRef"],
    ["hotspot.jni.DeleteGlobalRef.return", "\"%s\\n\",name", "DeleteGlobalRef"],
    ["hotspot.jni.DeleteLocalRef", "\"%s\\n\",name", "DeleteLocalRef"],
    ["hotspot.jni.DeleteLocalRef.return", "\"%s\\n\",name", "DeleteLocalRef"],
    ["hotspot.jni.DeleteWeakGlobalRef", "\"%s\\n\",name", "DeleteWeakGlobalRef"],
    ["hotspot.jni.DeleteWeakGlobalRef.return", "\"%s\\n\",name", "DeleteWeakGlobalRef"],
    ["hotspot.jni.DestroyJavaVM", "\"%s\\n\",name", "DestroyJavaVM"],
    ["hotspot.jni.DestroyJavaVM.return", "\"%sret=%d\\n\",name,ret", "DestroyJavaVMret=0"],
    ["hotspot.jni.DetachCurrentThread", "\"%s\\n\",name", "DetachCurrentThread"],
    ["hotspot.jni.DetachCurrentThread.return", "\"%sret=%d\\n\",name,ret", "DetachCurrentThreadret=0"],
    ["hotspot.jni.EnsureLocalCapacity", "\"%scap=%d\\n\",name,capacity", "EnsureLocalCapacitycap=10"],
    ["hotspot.jni.EnsureLocalCapacity.return", "\"%sret=%d\\n\",name,ret", "EnsureLocalCapacityret=0"],
    ["hotspot.jni.ExceptionCheck", "\"%s\\n\",name", "ExceptionCheck"],
    ["hotspot.jni.ExceptionCheck.return", "\"%sret=%d\\n\",name,ret", "ExceptionCheckret=1"],
    ["hotspot.jni.ExceptionClear", "\"%s\\n\",name", "ExceptionClear"],
    ["hotspot.jni.ExceptionClear.return", "\"%s\\n\",name", "ExceptionClear"],
    ["hotspot.jni.ExceptionDescribe", "\"%s\\n\",name", "ExceptionDescribe"],
    ["hotspot.jni.ExceptionDescribe.return", "\"%s\\n\",name", "ExceptionDescribe"],
    ["hotspot.jni.ExceptionOccurred", "\"%s\\n\",name", "ExceptionOccurred"],
    ["hotspot.jni.ExceptionOccurred.return", "\"%sret=%d\\n\",name,ret", "ExceptionOccurredret=[^0]"],
    ["hotspot.jni.FatalError", "\"%smsg=%s\\n\",name,msg", "FatalErrormsg=Intentional Crash: Ignore."],
    ["hotspot.jni.FindClass", "\"%sclass=%s\\n\",name,clazz", "FindClassclass=staptest/JNITestClass"],
    ["hotspot.jni.FindClass.return", "\"%sret=%d\\n\",name,ret", "FindClassret=[^0]"],
    ["hotspot.jni.FromReflectedField", "\"%s\\n\",name", "FromReflectedField"],
    ["hotspot.jni.FromReflectedField.return", "\"%s\\n\",name", "FromReflectedField"],
    ["hotspot.jni.FromReflectedMethod", "\"%s\\n\",name", "FromReflectedMethod"],
    ["hotspot.jni.FromReflectedMethod.return", "\"%s\\n\",name", "FromReflectedMethod"],
    ["hotspot.jni.GetArrayLength", "\"%s\\n\",name", "GetArrayLength"],
    ["hotspot.jni.GetArrayLength.return", "\"%sret=%d\\n\",name,ret", "GetArrayLengthret=5"],
    ["hotspot.jni.GetBooleanArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetBooleanArrayElementscp=0"],
    ["hotspot.jni.GetBooleanArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetBooleanArrayElementsret=[^0]"],
    ["hotspot.jni.GetBooleanArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetBooleanArrayRegionstart=0len=5"],
    ["hotspot.jni.GetBooleanArrayRegion.return", "\"%s\\n\",name", "GetBooleanArrayRegion"],
    ["hotspot.jni.GetBooleanField", "\"%s\\n\",name", "GetBooleanField"],
    ["hotspot.jni.GetBooleanField.return", "\"%sret=%d\\n\",name,ret", "GetBooleanFieldret=1"],
    ["hotspot.jni.GetByteArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetByteArrayElementscp=0"],
    ["hotspot.jni.GetByteArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetByteArrayElementsret=[^0]"],
    ["hotspot.jni.GetByteArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetByteArrayRegionstart=0len=5"],
    ["hotspot.jni.GetByteArrayRegion.return", "\"%s\\n\",name", "GetByteArrayRegion"],
    ["hotspot.jni.GetByteField", "\"%s\\n\",name", "GetByteField"],
    ["hotspot.jni.GetByteField.return", "\"%sret=%d\\n\",name,ret", "GetByteFieldret=0"],
    ["hotspot.jni.GetCharArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetCharArrayElementscp=0"],
    ["hotspot.jni.GetCharArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetCharArrayElementsret=[^0]"],
    ["hotspot.jni.GetCharArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetCharArrayRegionstart=0len=5"],
    ["hotspot.jni.GetCharArrayRegion.return", "\"%s\\n\",name", "GetCharArrayRegion"],
    ["hotspot.jni.GetCharField", "\"%s\\n\",name", "GetCharField"],
    ["hotspot.jni.GetCharField.return", "\"%sret=%d\\n\",name,ret", "GetCharFieldret=97"],
    ["hotspot.jni.GetCreatedJavaVMs", "\"%sbuflen=%d\\n\",name,buflen", "GetCreatedJavaVMsbuflen=1"],
    ["hotspot.jni.GetCreatedJavaVMs.return", "\"%sret=%d\\n\",name,ret", "GetCreatedJavaVMsret=0"],
    ["hotspot.jni.GetDefaultJavaVMInitArgs", "\"%s\\n\",name", "GetDefaultJavaVMInitArgs"],
    ["hotspot.jni.GetDefaultJavaVMInitArgs.return", "\"%sret=%d\\n\",name,ret", "GetDefaultJavaVMInitArgsret=0"],
    ["hotspot.jni.GetDirectBufferAddress", "\"%s\\n\",name", "GetDirectBufferAddress"],
    ["hotspot.jni.GetDirectBufferAddress.return", "\"%sret=%d\\n\",name,ret", "GetDirectBufferAddressret=[^0]"],
    ["hotspot.jni.GetDirectBufferCapacity", "\"%s\\n\",name", "GetDirectBufferCapacity"],
    ["hotspot.jni.GetDirectBufferCapacity.return", "\"%sret=%d\\n\",name,ret", "GetDirectBufferCapacityret=128"],
    ["hotspot.jni.GetDoubleArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetDoubleArrayElementscp=0"],
    ["hotspot.jni.GetDoubleArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetDoubleArrayElementsret=[^0]"],
    ["hotspot.jni.GetDoubleArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetDoubleArrayRegionstart=0len=5"],
    ["hotspot.jni.GetDoubleArrayRegion.return", "\"%s\\n\",name", "GetDoubleArrayRegion"],
    ["hotspot.jni.GetDoubleField", "\"%s\\n\",name", "GetDoubleField"],
    ["hotspot.jni.GetDoubleField.return", "\"%s\\n\",name", "GetDoubleField"],
    ["hotspot.jni.GetEnv", "\"%sver=%x\\n\",name,version", "GetEnvver=10006"],
    ["hotspot.jni.GetEnv.return", "\"%sret=%d\\n\",name,ret", "GetEnvret=0"],
    ["hotspot.jni.GetFieldID", "\"%sfield=%ssig=%s\\n\",name,field,sig", "GetFieldIDfield=myBooleansig=Z"],
    ["hotspot.jni.GetFieldID.return", "\"%sret=%d\\n\",name,ret", "GetFieldIDret=[^0]"],
    ["hotspot.jni.GetFloatArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetFloatArrayElementscp=0"],
    ["hotspot.jni.GetFloatArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetFloatArrayElementsret=[^0]"],
    ["hotspot.jni.GetFloatArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetFloatArrayRegionstart=0len=5"],
    ["hotspot.jni.GetFloatArrayRegion.return", "\"%s\\n\",name", "GetFloatArrayRegion"],
    ["hotspot.jni.GetFloatField", "\"%s\\n\",name", "GetFloatField"],
    ["hotspot.jni.GetFloatField.return", "\"%s\\n\",name", "GetFloatField"],
    ["hotspot.jni.GetIntArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetIntArrayElementscp=0"],
    ["hotspot.jni.GetIntArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetIntArrayElementsret=[^0]"],
    ["hotspot.jni.GetIntArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetIntArrayRegionstart=0len=5"],
    ["hotspot.jni.GetIntArrayRegion.return", "\"%s\\n\",name", "GetIntArrayRegion"],
    ["hotspot.jni.GetIntField", "\"%s\\n\",name", "GetIntField"],
    ["hotspot.jni.GetIntField.return", "\"%sret=%d\\n\",name,ret", "GetIntFieldret=4"],
    ["hotspot.jni.GetJavaVM", "\"%s\\n\",name", "GetJavaVM"],
    ["hotspot.jni.GetJavaVM.return", "\"%sret=%d\\n\",name,ret", "GetJavaVMret=0"],
    ["hotspot.jni.GetLongArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetLongArrayElementscp=0"],
    ["hotspot.jni.GetLongArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetLongArrayElementsret=[^0]"],
    ["hotspot.jni.GetLongArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetLongArrayRegionstart=0len=5"],
    ["hotspot.jni.GetLongArrayRegion.return", "\"%s\\n\",name", "GetLongArrayRegion"],
    ["hotspot.jni.GetLongField", "\"%s\\n\",name", "GetLongField"],
    ["hotspot.jni.GetLongField.return", "\"%sret=%d\\n\",name,ret", "GetLongFieldret=8"],
    ["hotspot.jni.GetMethodID", "\"%smethod=%ssig=%s\\n\",name,method,sig", "GetMethodIDmethod=getBooleansig=()Z"],
    ["hotspot.jni.GetMethodID.return", "\"%sret=%d\\n\",name,ret", "GetMethodIDret=[^0]"],
    ["hotspot.jni.GetObjectArrayElement", "\"%si=%d\\n\",name,index", "GetObjectArrayElementi=1"],
    ["hotspot.jni.GetObjectArrayElement.return", "\"%sret=%d\\n\",name,ret", "GetObjectArrayElementret=[^0]"],
    ["hotspot.jni.GetObjectClass", "\"%s\\n\",name", "GetObjectClass"],
    ["hotspot.jni.GetObjectClass.return", "\"%sret=%d\\n\",name,ret", "GetObjectClassret=[^0]"],
    ["hotspot.jni.GetObjectField", "\"%s\\n\",name", "GetObjectField"],
    ["hotspot.jni.GetObjectField.return", "\"%sret=%d\\n\",name,ret", "GetObjectFieldret=[^0]"],
    ["hotspot.jni.GetObjectRefType", "\"%s\\n\",name", "GetObjectRefType"],
    ["hotspot.jni.GetObjectRefType.return", "\"%sret=%d\\n\",name,ret", "GetObjectRefTyperet=2"],
    ["hotspot.jni.GetPrimitiveArrayCritical", "\"%s\\n\",name", "GetPrimitiveArrayCritical"],
    ["hotspot.jni.GetPrimitiveArrayCritical.return", "\"%sret=%d\\n\",name,ret", "GetPrimitiveArrayCriticalret=[^0]"],
    ["hotspot.jni.GetShortArrayElements", "\"%scp=%d\\n\",name,iscopy", "GetShortArrayElementscp=0"],
    ["hotspot.jni.GetShortArrayElements.return", "\"%sret=%d\\n\",name,ret", "GetShortArrayElementsret=[^0]"],
    ["hotspot.jni.GetShortArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "GetShortArrayRegionstart=0len=5"],
    ["hotspot.jni.GetShortArrayRegion.return", "\"%s\\n\",name", "GetShortArrayRegion"],
    ["hotspot.jni.GetShortField", "\"%s\\n\",name", "GetShortField"],
    ["hotspot.jni.GetShortField.return", "\"%sret=%d\\n\",name,ret", "GetShortFieldret=2"],
    ["hotspot.jni.GetStaticBooleanField", "\"%s\\n\",name", "GetStaticBooleanField"],
    ["hotspot.jni.GetStaticBooleanField.return", "\"%sret=%d\\n\",name,ret", "GetStaticBooleanFieldret=0"],
    ["hotspot.jni.GetStaticByteField", "\"%s\\n\",name", "GetStaticByteField"],
    ["hotspot.jni.GetStaticByteField.return", "\"%sret=%d\\n\",name,ret", "GetStaticByteFieldret=1"],
    ["hotspot.jni.GetStaticCharField", "\"%s\\n\",name", "GetStaticCharField"],
    ["hotspot.jni.GetStaticCharField.return", "\"%sret=%d\\n\",name,ret", "GetStaticCharFieldret=98"],
    ["hotspot.jni.GetStaticDoubleField", "\"%s\\n\",name", "GetStaticDoubleField"],
    ["hotspot.jni.GetStaticDoubleField.return", "\"%s\\n\",name", "GetStaticDoubleField"],
    ["hotspot.jni.GetStaticFieldID", "\"%sfield=%ssig=%s\\n\",name,field,sig", "GetStaticFieldIDfield=myStaticBooleansig=Z"],
    ["hotspot.jni.GetStaticFieldID.return", "\"%sret=%d\\n\",name,ret", "GetStaticFieldIDret=[^0]"],
    ["hotspot.jni.GetStaticFloatField", "\"%s\\n\",name", "GetStaticFloatField"],
    ["hotspot.jni.GetStaticFloatField.return", "\"%s\\n\",name", "GetStaticFloatField"],
    ["hotspot.jni.GetStaticIntField", "\"%s\\n\",name", "GetStaticIntField"],
    ["hotspot.jni.GetStaticIntField.return", "\"%sret=%d\\n\",name,ret", "GetStaticIntFieldret=32"],
    ["hotspot.jni.GetStaticLongField", "\"%s\\n\",name", "GetStaticLongField"],
    ["hotspot.jni.GetStaticLongField.return", "\"%sret=%d\\n\",name,ret", "GetStaticLongFieldret=64"],
    ["hotspot.jni.GetMethodID", "\"%smethod=%ssig=%s\\n\",name,method,sig", "GetMethodIDmethod=getBooleansig=()Z"],
    ["hotspot.jni.GetStaticMethodID.return", "\"%sret=%d\\n\",name,ret", "GetStaticMethodIDret=[^0]"],
    ["hotspot.jni.GetStaticObjectField", "\"%s\\n\",name", "GetStaticObjectField"],
    ["hotspot.jni.GetStaticObjectField.return", "\"%sret=%d\\n\",name,ret", "GetStaticObjectFieldret=[^0]"],
    ["hotspot.jni.GetStaticShortField", "\"%s\\n\",name", "GetStaticShortField"],
    ["hotspot.jni.GetStaticShortField.return", "\"%sret=%d\\n\",name,ret", "GetStaticShortFieldret=16"],
    ["hotspot.jni.GetStringChars", "\"%scp=%d\\n\",name,iscopy", "GetStringCharscp=0"],
    ["hotspot.jni.GetStringChars.return", "\"%sret=%d\\n\",name,ret", "GetStringCharsret=[^0]"],
    ["hotspot.jni.GetStringCritical", "\"%scp=%d\\n\",name,iscopy", "GetStringCriticalcp=0"],
    ["hotspot.jni.GetStringCritical.return", "\"%sret=%d\\n\",name,ret", "GetStringCriticalret=[^0]"],
    ["hotspot.jni.GetStringLength", "\"%s\\n\",name", "GetStringLength"],
    ["hotspot.jni.GetStringLength.return", "\"%sret=%d\\n\",name,ret", "GetStringLengthret=4"],
    ["hotspot.jni.GetStringRegion", "\"%sst=%dlen=%d\\n\",name,start,len", "GetStringRegionst=1len=2"],
    ["hotspot.jni.GetStringRegion.return", "\"%s\\n\",name", "GetStringRegion"],
    ["hotspot.jni.GetStringUTFChars", "\"%scp=%d\\n\",name,iscopy", "GetStringUTFCharscp=0"],
    ["hotspot.jni.GetStringUTFChars.return", "\"%sret=%s\\n\",name,ret", "GetStringUTFCharsret=WORD"],
    ["hotspot.jni.GetStringUTFLength", "\"%s\\n\",name", "GetStringUTFLength"],
    ["hotspot.jni.GetStringUTFLength.return", "\"%sret=%d\\n\",name,ret", "GetStringUTFLengthret=6"],
    ["hotspot.jni.GetStringUTFRegion", "\"%sst=%dlen=%d\\n\",name,start,len", "GetStringUTFRegionst=1len=2"],
    ["hotspot.jni.GetStringUTFRegion.return", "\"%s\\n\",name", "GetStringUTFRegion"],
    ["hotspot.jni.GetSuperclass", "\"%s\\n\",name", "GetSuperclass"],
    ["hotspot.jni.GetSuperclass.return", "\"%sret=%d\\n\",name,ret", "GetSuperclassret=[^0]"],
    ["hotspot.jni.GetVersion", "\"%s\\n\",name", "GetVersion"],
    ["hotspot.jni.GetVersion.return", "\"%sret=%x\\n\",name,ret", "GetVersionret=10006"],
    ["hotspot.jni.IsAssignableFrom", "\"%s\\n\",name", "IsAssignableFrom"],
    ["hotspot.jni.IsAssignableFrom.return", "\"%sret=%d\\n\",name,ret", "IsAssignableFromret=1"],
    ["hotspot.jni.IsInstanceOf", "\"%s\\n\",name", "IsInstanceOf"],
    ["hotspot.jni.IsInstanceOf.return", "\"%sret=%d\\n\",name,ret", "IsInstanceOfret=1"],
    ["hotspot.jni.IsSameObject", "\"%s\\n\",name", "IsSameObject"],
    ["hotspot.jni.IsSameObject.return", "\"%sret=%d\\n\",name,ret", "IsSameObjectret=1"],
    ["hotspot.jni.MonitorEnter", "\"%s\\n\",name", "MonitorEnter"],
    ["hotspot.jni.MonitorEnter.return", "\"%sret=%d\\n\",name,ret", "MonitorEnterret=0"],
    ["hotspot.jni.MonitorExit", "\"%s\\n\",name", "MonitorExit"],
    ["hotspot.jni.MonitorExit.return", "\"%sret=%d\\n\",name,ret", "MonitorExitret=0"],
    ["hotspot.jni.NewBooleanArray", "\"%slen=%d\\n\",name,length", "NewBooleanArraylen=5"],
    ["hotspot.jni.NewBooleanArray.return", "\"%sret=%d\\n\",name,ret", "NewBooleanArrayret=[^0]"],
    ["hotspot.jni.NewByteArray", "\"%slen=%d\\n\",name,length", "NewByteArraylen=5"],
    ["hotspot.jni.NewByteArray.return", "\"%sret=%d\\n\",name,ret", "NewByteArrayret=[^0]"],
    ["hotspot.jni.NewCharArray", "\"%slen=%d\\n\",name,length", "NewCharArraylen=5"],
    ["hotspot.jni.NewCharArray.return", "\"%sret=%d\\n\",name,ret", "NewCharArrayret=[^0]"],
    ["hotspot.jni.NewDirectByteBuffer", "\"%ssize=%d\\n\",name,size", "NewDirectByteBuffersize=128"],
    ["hotspot.jni.NewDirectByteBuffer.return", "\"%sret=%d\\n\",name,ret", "NewDirectByteBufferret=[^0]"],
    ["hotspot.jni.NewDoubleArray", "\"%slen=%d\\n\",name,length", "NewDoubleArraylen=5"],
    ["hotspot.jni.NewDoubleArray.return", "\"%sret=%d\\n\",name,ret", "NewDoubleArrayret=[^0]"],
    ["hotspot.jni.NewFloatArray", "\"%slen=%d\\n\",name,length", "NewFloatArraylen=5"],
    ["hotspot.jni.NewFloatArray.return", "\"%sret=%d\\n\",name,ret", "NewFloatArrayret=[^0]"],
    ["hotspot.jni.NewGlobalRef", "\"%s\\n\",name", "NewGlobalRef"],
    ["hotspot.jni.NewGlobalRef.return", "\"%sret=%d\\n\",name,ret", "NewGlobalRefret=[^0]"],
    ["hotspot.jni.NewIntArray", "\"%slen=%d\\n\",name,length", "NewIntArraylen=5"],
    ["hotspot.jni.NewIntArray.return", "\"%sret=%d\\n\",name,ret", "NewIntArrayret=[^0]"],
    ["hotspot.jni.NewLocalRef", "\"%s\\n\",name", "NewLocalRef"],
    ["hotspot.jni.NewLocalRef.return", "\"%sret=%d\\n\",name,ret", "NewLocalRefret=[^0]"],
    ["hotspot.jni.NewLongArray", "\"%slen=%d\\n\",name,length", "NewLongArraylen=5"],
    ["hotspot.jni.NewLongArray.return", "\"%sret=%d\\n\",name,ret", "NewLongArrayret=[^0]"],
    ["hotspot.jni.NewObjectA", "\"%s\\n\",name", "NewObjectA"],
    ["hotspot.jni.NewObjectA.return", "\"%sret=%d\\n\",name,ret", "NewObjectAret=[^0]"],
    ["hotspot.jni.NewObjectArray", "\"%slen=%dinit=%d\\n\",name,length,initial", "NewObjectArraylen=5init=0"],
    ["hotspot.jni.NewObjectArray.return", "\"%sret=%d\\n\",name,ret", "NewObjectArrayret=[^0]"],
    ["hotspot.jni.NewObject", "\"%s\\n\",name", "NewObject"],
    ["hotspot.jni.NewObject.return", "\"%sret=%d\\n\",name,ret", "NewObjectret=[^0]"],
    ["hotspot.jni.NewObjectV", "\"%s\\n\",name", "NewObjectV"],
    ["hotspot.jni.NewObjectV.return", "\"%sret=%d\\n\",name,ret", "NewObjectVret=[^0]"],
    ["hotspot.jni.NewShortArray", "\"%slen=%d\\n\",name,length", "NewShortArraylen=5"],
    ["hotspot.jni.NewShortArray.return", "\"%sret=%d\\n\",name,ret", "NewShortArrayret=[^0]"],
    ["hotspot.jni.NewString", "\"%slen=%d\\n\",name,len", "NewStringlen=4"],
    ["hotspot.jni.NewString.return", "\"%sret=%d\\n\",name,ret", "NewStringret=[^0]"],
    ["hotspot.jni.NewStringUTF", "\"%sbytes=%s\\n\",name,bytes", "NewStringUTFbytes=WORD"],
    ["hotspot.jni.NewStringUTF.return", "\"%sret=%d\\n\",name,ret", "NewStringUTFret=[^0]"],
    ["hotspot.jni.NewWeakGlobalRef", "\"%s\\n\",name", "NewWeakGlobalRef"],
    ["hotspot.jni.NewWeakGlobalRef.return", "\"%sret=%d\\n\",name,ret", "NewWeakGlobalRefret=[^0]"],
    ["hotspot.jni.PopLocalFrame", "\"%s\\n\",name", "PopLocalFrame"],
    ["hotspot.jni.PopLocalFrame.return", "\"%sret=%d\\n\",name,ret", "PopLocalFrameret=0"],
    ["hotspot.jni.PushLocalFrame", "\"%scap=%d\\n\",name,capacity", "PushLocalFramecap=10"],
    ["hotspot.jni.PushLocalFrame.return", "\"%sret=%d\\n\",name,ret", "PushLocalFrameret=0"],
    ["hotspot.jni.RegisterNatives", "\"%s\\n\",name", "RegisterNatives"],
    ["hotspot.jni.RegisterNatives.return", "\"%sret=%d\\n\",name,ret", "RegisterNativesret=0"],
    ["hotspot.jni.ReleaseBooleanArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseBooleanArrayElementsmode=2"],
    ["hotspot.jni.ReleaseBooleanArrayElements.return", "\"%s\\n\",name", "ReleaseBooleanArrayElements"],
    ["hotspot.jni.ReleaseByteArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseByteArrayElementsmode=2"],
    ["hotspot.jni.ReleaseByteArrayElements.return", "\"%s\\n\",name", "ReleaseByteArrayElements"],
    ["hotspot.jni.ReleaseCharArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseCharArrayElementsmode=2"],
    ["hotspot.jni.ReleaseCharArrayElements.return", "\"%s\\n\",name", "ReleaseCharArrayElements"],
    ["hotspot.jni.ReleaseDoubleArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseDoubleArrayElementsmode=2"],
    ["hotspot.jni.ReleaseDoubleArrayElements.return", "\"%s\\n\",name", "ReleaseDoubleArrayElements"],
    ["hotspot.jni.ReleaseFloatArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseFloatArrayElementsmode=2"],
    ["hotspot.jni.ReleaseFloatArrayElements.return", "\"%s\\n\",name", "ReleaseFloatArrayElements"],
    ["hotspot.jni.ReleaseIntArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseIntArrayElementsmode=2"],
    ["hotspot.jni.ReleaseIntArrayElements.return", "\"%s\\n\",name", "ReleaseIntArrayElements"],
    ["hotspot.jni.ReleaseLongArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseLongArrayElementsmode=2"],
    ["hotspot.jni.ReleaseLongArrayElements.return", "\"%s\\n\",name", "ReleaseLongArrayElements"],
    ["hotspot.jni.ReleasePrimitiveArrayCritical", "\"%smode=%d\\n\",name,mode", "ReleasePrimitiveArrayCriticalmode=2"],
    ["hotspot.jni.ReleasePrimitiveArrayCritical.return", "\"%s\\n\",name", "ReleasePrimitiveArrayCritical"],
    ["hotspot.jni.ReleaseShortArrayElements", "\"%smode=%d\\n\",name,mode", "ReleaseShortArrayElementsmode=2"],
    ["hotspot.jni.ReleaseShortArrayElements.return", "\"%s\\n\",name", "ReleaseShortArrayElements"],
    ["hotspot.jni.ReleaseStringChars", "\"%s\\n\",name", "ReleaseStringChars"],
    ["hotspot.jni.ReleaseStringChars.return", "\"%s\\n\",name", "ReleaseStringChars"],
    ["hotspot.jni.ReleaseStringCritical", "\"%s\\n\",name", "ReleaseStringCritical"],
    ["hotspot.jni.ReleaseStringCritical.return", "\"%s\\n\",name", "ReleaseStringCritical"],
    ["hotspot.jni.ReleaseStringUTFChars", "\"%sutf=%s\\n\",name,utf", "ReleaseStringUTFCharsutf=WORD"],
    ["hotspot.jni.ReleaseStringUTFChars.return", "\"%s\\n\",name", "ReleaseStringUTFChars"],
    ["hotspot.jni.SetBooleanArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetBooleanArrayRegionstart=0len=5"],
    ["hotspot.jni.SetBooleanArrayRegion.return", "\"%s\\n\",name", "SetBooleanArrayRegion"],
    ["hotspot.jni.SetBooleanField", "\"%sval=%d\\n\",name,value", "SetBooleanFieldval=1"],
    ["hotspot.jni.SetBooleanField.return", "\"%s\\n\",name", "SetBooleanField"],
    ["hotspot.jni.SetByteArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetByteArrayRegionstart=0len=5"],
    ["hotspot.jni.SetByteArrayRegion.return", "\"%s\\n\",name", "SetByteArrayRegion"],
    ["hotspot.jni.SetByteField", "\"%sval=%d\\n\",name,value", "SetByteFieldval=2"],
    ["hotspot.jni.SetByteField.return", "\"%s\\n\",name", "SetByteField"],
    ["hotspot.jni.SetCharArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetCharArrayRegionstart=0len=5"],
    ["hotspot.jni.SetCharArrayRegion.return", "\"%s\\n\",name", "SetCharArrayRegion"],
    ["hotspot.jni.SetCharField", "\"%sval=%d\\n\",name,value", "SetCharFieldval=65"],
    ["hotspot.jni.SetCharField.return", "\"%s\\n\",name", "SetCharField"],
    ["hotspot.jni.SetDoubleArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetDoubleArrayRegionstart=0len=5"],
    ["hotspot.jni.SetDoubleArrayRegion.return", "\"%s\\n\",name", "SetDoubleArrayRegion"],
    ["hotspot.jni.SetDoubleField", "\"%s\\n\",name", "SetDoubleField"],
    ["hotspot.jni.SetDoubleField.return", "\"%s\\n\",name", "SetDoubleField"],
    ["hotspot.jni.SetFloatArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetFloatArrayRegionstart=0len=5"],
    ["hotspot.jni.SetFloatArrayRegion.return", "\"%s\\n\",name", "SetFloatArrayRegion"],
    ["hotspot.jni.SetFloatField", "\"%s\\n\",name", "SetFloatField"],
    ["hotspot.jni.SetFloatField.return", "\"%s\\n\",name", "SetFloatField"],
    ["hotspot.jni.SetIntArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetIntArrayRegionstart=0len=5"],
    ["hotspot.jni.SetIntArrayRegion.return", "\"%s\\n\",name", "SetIntArrayRegion"],
    ["hotspot.jni.SetIntField", "\"%sval=%d\\n\",name,value", "SetIntFieldval=7"],
    ["hotspot.jni.SetIntField.return", "\"%s\\n\",name", "SetIntField"],
    ["hotspot.jni.SetLongArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetLongArrayRegionstart=0len=5"],
    ["hotspot.jni.SetLongArrayRegion.return", "\"%s\\n\",name", "SetLongArrayRegion"],
    ["hotspot.jni.SetLongField", "\"%sval=%d\\n\",name,value", "SetLongFieldval=13"],
    ["hotspot.jni.SetLongField.return", "\"%s\\n\",name", "SetLongField"],
    ["hotspot.jni.SetObjectArrayElement", "\"%s\\n\",name", "SetObjectArrayElement"],
    ["hotspot.jni.SetObjectArrayElement.return", "\"%s\\n\",name", "SetObjectArrayElement"],
    ["hotspot.jni.SetObjectField", "\"%s\\n\",name", "SetObjectField"],
    ["hotspot.jni.SetObjectField.return", "\"%s\\n\",name", "SetObjectField"],
    ["hotspot.jni.SetShortArrayRegion", "\"%sstart=%dlen=%d\\n\",name,start,len", "SetShortArrayRegionstart=0len=5"],
    ["hotspot.jni.SetShortArrayRegion.return", "\"%s\\n\",name", "SetShortArrayRegion"],
    ["hotspot.jni.SetShortField", "\"%sval=%d\\n\",name,value", "SetShortFieldval=11"],
    ["hotspot.jni.SetShortField.return", "\"%s\\n\",name", "SetShortField"],
    ["hotspot.jni.SetStaticBooleanField", "\"%sval=%d\\n\",name,value", "SetStaticBooleanFieldval=1"],
    ["hotspot.jni.SetStaticBooleanField.return", "\"%s\\n\",name", "SetStaticBooleanField"],
    ["hotspot.jni.SetStaticByteField", "\"%sval=%d\\n\",name,value", "SetStaticByteFieldval=2"],
    ["hotspot.jni.SetStaticByteField.return", "\"%s\\n\",name", "SetStaticByteField"],
    ["hotspot.jni.SetStaticCharField", "\"%sval=%d\\n\",name,value", "SetStaticCharFieldval=65"],
    ["hotspot.jni.SetStaticCharField.return", "\"%s\\n\",name", "SetStaticCharField"],
    ["hotspot.jni.SetStaticDoubleField", "\"%s\\n\",name", "SetStaticDoubleField"],
    ["hotspot.jni.SetStaticDoubleField.return", "\"%s\\n\",name", "SetStaticDoubleField"],
    ["hotspot.jni.SetStaticFloatField", "\"%s\\n\",name", "SetStaticFloatField"],
    ["hotspot.jni.SetStaticFloatField.return", "\"%s\\n\",name", "SetStaticFloatField"],
    ["hotspot.jni.SetStaticIntField", "\"%sval=%d\\n\",name,value", "SetStaticIntFieldval=7"],
    ["hotspot.jni.SetStaticIntField.return", "\"%s\\n\",name", "SetStaticIntField"],
    ["hotspot.jni.SetStaticLongField", "\"%sval=%d\\n\",name,value", "SetStaticLongFieldval=13"],
    ["hotspot.jni.SetStaticLongField.return", "\"%s\\n\",name", "SetStaticLongField"],
    ["hotspot.jni.SetStaticObjectField", "\"%s\\n\",name", "SetStaticObjectField"],
    ["hotspot.jni.SetStaticObjectField.return", "\"%s\\n\",name", "SetStaticObjectField"],
    ["hotspot.jni.SetStaticShortField", "\"%sval=%d\\n\",name,value", "SetStaticShortFieldval=11"],
    ["hotspot.jni.SetStaticShortField.return", "\"%s\\n\",name", "SetStaticShortField"],
    ["hotspot.jni.Throw", "\"%s\\n\",name", "Throw"],
    ["hotspot.jni.Throw.return", "\"%sret=%d\\n\",name,ret", "Throwret=0"],
    ["hotspot.jni.ThrowNew", "\"%smsg=%s\\n\",name,msg", "ThrowNewmsg=This exception is for testing purposes only."],
    ["hotspot.jni.ThrowNew.return", "\"%sret=%d\\n\",name,ret", "ThrowNewret=0"],
    ["hotspot.jni.ToReflectedField", "\"%s\\n\",name", "ToReflectedField"],
    ["hotspot.jni.ToReflectedField.return", "\"%sret=%d\\n\",name,ret", "ToReflectedFieldret=[^0]"],
    ["hotspot.jni.ToReflectedMethod", "\"%s\\n\",name", "ToReflectedMethod"],
    ["hotspot.jni.ToReflectedMethod.return", "\"%sret=%d\\n\",name,ret", "ToReflectedMethodret=[^0]"],
    ["hotspot.jni.UnregisterNatives", "\"%s\\n\",name", "UnregisterNatives"],
    ["hotspot.jni.UnregisterNatives.return", "\"%sret=%d\\n\",name,ret", "UnregisterNativesret=0"]);

# To test for known probe prefix.  Determines main type of test run.
my $hs_regex = "^hotspot\.";
my $jni_regex = "^hotspot\.jni\.";

# Status of test run.
my $working_count = 0;
my $undetected_count = 0;
my $broken_count = 0;
my $working_jstack = 0;
my $broken_jstack = 0;

# Stuffed based on argument(s), used as argument to stap executable.
my @tapset_dirs = ();

# Set based on arguments, used to during compilation and/or running of tests.
my $ignore_system_tapset = "";
my $java_exec = "";
my $javac_exec = "";
my $jvm_dir = "";
my $jvm_so = "";
my $test_sourcedir = ".";
my @include_dirs = ();
my $run_test_probes = 1;
my $run_test_jstack = 1;


### MAIN BODY
#     Short and sweet.
process_args();
log_preamble();
build_tests();

my $can_probe = can_run_probes();
my @detected_probes;

if ($run_test_probes) {
  @detected_probes = detect_probes(@probestrings);
  if ($can_probe) {
    test_probes(@detected_probes);
  }
}

if ($run_test_jstack && $can_probe) {
  # Default, no arguments.
  test_jstack("");
  # Explicitly turn on compressed oops.
  test_jstack("-XX:+UseCompressedOops");
  # Explicitly turn off compressed oops.
  test_jstack("-XX:-UseCompressedOops");
  # Force some shift value for compressed oops by having a 4GB+ heap.
  test_jstack("-XX:+UseCompressedOops -Xmx5G");
  # Explicitly disable compressed oops, but use large heap anyway.
  test_jstack("-XX:-UseCompressedOops -Xmx5G");
}

summarize();
log_postamble();
clean_up();
exit($broken_count | $undetected_count);

### PRIMARY SUBROUTINES
#     These are called by the main body of the script.

# Uses Getopt::Std::getopts() to grab user arguments, then performs further
#     processing to ensure valid combination of args and set several variables
#     based on args. 
sub process_args {
    die "Try \"jstaptest.pl --help\" for usage information.\n"
            if (!getopts('B:A:J:o:a:S:pj')
                || ($opt_o && $opt_a)   # -o and -a are mutually exclusive.
                || ($opt_p && $opt_j)); # -p and -j are mutually exclusive.
    if ($opt_B && $opt_A) {
        die "Directory $opt_B not found." unless (-d $opt_B);
        die "Directory $opt_B/j2sdk-image/tapset not found.\nTry rebuilding IcedTea with systemtap support.\n"
                unless (-d "$opt_B/j2sdk-image/tapset");
        push(@tapset_dirs, "-I$opt_B/j2sdk-image/tapset");
        set_java_vars("$opt_B/j2sdk-image", $opt_A);
        $ignore_system_tapset = "SYSTEMTAP_TAPSET=\"\"";
    }
    elsif ($opt_J) {
        set_java_vars($opt_J, get_arch_dir());
        
    }
    else {
        die "Try \"./jstaptest.pl --help\" for usage information.\n";
    }

    if ($opt_S) {
        die "Directory $opt_S not found." unless (-d $opt_S);
        $test_sourcedir = "$opt_S";
    }

    if ($opt_o) {
        $logfile_name = $opt_o;
        mkpath(dirname($opt_o)) or
                die "Couldn't make enclosing directory for $opt_o\n$!"
                unless (-d dirname($opt_o));
        open($log_file, '>', $opt_o) or
                die "Couldn't open log file: $opt_a\n$!";
    }
    if ($opt_a) {
        $logfile_name = $opt_a;
        mkpath(dirname($opt_a)) or
                die "Couldn't make enclosing directory for $opt_a\n$!"
                unless (-d dirname($opt_a));
        open($log_file, '>>', $opt_a) or
                die "Couldn't open log file: $opt_a\n$!";
    }
    if ($opt_p) {
      $run_test_probes = 1;
      $run_test_jstack = 0;
    }
    if ($opt_j) {
      $run_test_probes = 0;
      $run_test_jstack = 1;
    }
}

# Any text that should precede a test run in the log file goes here.
sub log_preamble {
    just_log("###############################################################");
    just_log("Start of test run.\n" . gmtime());
}

# Tests consist of a number of C and Java files.  These need to be compiled.
sub build_tests {
    log_and_print("Compiling tests.");
    my $compile_command = "$javac_exec -d ./ $test_sourcedir/*.java";
    just_log($compile_command);
    system($compile_command);
    if ($? != 0) {
        log_and_print("Error compiling one or more .java files.");
        clean_up();
        die "Cannot compile tests.\n";
    }
    $compile_command = "gcc " . join(' ', @include_dirs) .
            " -c -fPIC $test_sourcedir/JNITestClass.c -o JNITestClass.o";
    just_log($compile_command);
    system($compile_command);
    if ($? != 0) {
        log_and_print("Error compiling JNITestClass.o");
        clean_up();
        die "Cannot compile tests.\n";
    }
    $compile_command = "gcc -shared -o libJNITestClass.so -fPIC JNITestClass.o";
    just_log($compile_command);
    system($compile_command);
    if ($? != 0) {
        log_and_print("Error building libJNITestClass.so");
        clean_up();
        die "Cannot compile tests.\n";
    }
    $compile_command = "gcc " . join(' ', @include_dirs) .
                       " -pthread -L$jvm_dir -L. -lJNITestClass $jvm_so" .
                       " -o JNIStapTest $test_sourcedir/JNIStapTest.c";
    just_log($compile_command);
    system($compile_command);
    if ($? != 0) {
        log_and_print("Error compiling JNIStapTest");
        clean_up();
        die "Cannot compile tests.\n";
    }
}

# Filter out the list of probes.  If Systemtap cannot locate a probe using the
#     -l argument, it makes little sense to try to run a script based on it.
#     This also means we can detect this case as a distinct failure mode.
sub detect_probes {
    log_and_print("Testing if systemtap can match probes.");
    my @probes_detected = ();
    my ($probe_name, $probe_printargs, $probe_output, $stap_pre, $stap_command,
            @sysargs);
    $stap_pre = "$ignore_system_tapset /usr/bin/stap " . join(' ', @tapset_dirs);
    foreach my $probe_index (0..$#_) {
        $probe_name = $_[$probe_index][0];
        $probe_printargs = $_[$probe_index][1];
        $probe_output = $_[$probe_index][2];
        $stap_command = "$stap_pre -L $probe_name 2>&1 | grep -q \"^$probe_name\"";
        just_log($stap_command);
	print(".");
        system($stap_command);
        if ($? != 0) {
            print("\n");
            log_and_print("Probe $probe_name not found.");
            $undetected_count++;
        }
        else {
            just_log("Probe $probe_name found.");
            push(@probes_detected, [$probe_name, $probe_printargs,
                    $probe_output]);
        }
    }
    print("\n");
    return @probes_detected;
}

# Check whether we can run stap while probing.
# This needs extra user privs. If not, we only run the detect_probes()
# test, but not the test_probes() test.
sub can_run_probes {
    log_and_print("Check whether we have enough privs to run systemtap script...");
    my $stap_command = "/usr/bin/stap -e 'probe begin { log(\"Hello World\"); exit(); }'";
    just_log($stap_command);
    my $result = `$stap_command 2>&1`;
    if ($? != 0) {
	# First few error lines give a hint...
	print(join("\n", (split /\n/, $result)[0..5]), "\n");
	just_log($result);
        log_and_print("Cannot run simple stap script, skipping probe tests.");
        return 0;
    }
    print("OK\n");
    return 1;
}

# For each probe, run a stap script using the -c command to have it load
#     and unload automatically around the execution of a single command.  This
#     command will be the running of a java program (in the case of probes
#     from the hotspot.stp tapset) or a C program which uses the JNI
#     Invocation API (in the case of probes from the hotspot_jni.stp tapset),
#     which is designed to trigger the named probe in as minimal of a test
#     case as possible.  Associated with each probe is a format string (with
#     variables) that is called in a printf statement within the stap script,
#     and a regex designed to resemble the expected output of said printf
#     statement.
sub test_probes {
    log_and_print("Testing if detected probes work as expected.  This may take a while...");
    my ($probe_name, $probe_suffix, $probe_printargs, $probe_output,
            $stap_pre, $stap_command, $jvm_xxarg);
    $stap_pre = "/usr/bin/stap " . join(' ', @tapset_dirs);
    foreach my $probe_index (0..$#_) {
        $jvm_xxarg = "";
        $probe_name = $_[$probe_index][0];
        $probe_suffix = $probe_name;
        $probe_printargs = $_[$probe_index][1];
        $probe_output = $_[$probe_index][2];
        $stap_command = "$stap_pre -e 'probe $probe_name { printf($probe_printargs) }' -c";
        if ($probe_name =~ m/($jni_regex)/) {
            # JNI probes are triggered by calling a C program which uses the
            # invocation API on which the probes are based.
            $probe_suffix =~ s/($jni_regex)//;
            # The test against the jni function entry and return probes are
            # identical.
            $probe_suffix =~ s/\.return$//;
            $stap_command = "$stap_command 'export LD_LIBRARY_PATH=.:$jvm_dir && ./JNIStapTest $probe_suffix'";
            if ($probe_suffix =~ m/^FatalError$/) {
                # This test intentionally crashes the JVM, generating output
                # on stderr.  We don't want to see this noise.
                $stap_command = "$stap_command 2>&1";
            }
        }
        elsif ($probe_name =~ m/($hs_regex)/) {
            # Hotspot probes are triggered by calling a Java program which sets
            # up appropriate conditions in the JVM to hit the probe points.
            $probe_suffix =~ s/($hs_regex)//;
            # Some probes are optimized out in the default JVM configuration, so
            # we need some special arguments.
            if ($probe_suffix =~ m/^monitor/) {
                $jvm_xxarg = "-XX:+DTraceMonitorProbes";
            }
            elsif ($probe_suffix =~ m/^method_(entry|return)$/) {
                $jvm_xxarg = "-XX:+DTraceMethodProbes";
            }
            elsif ($probe_suffix =~ m/^object_alloc$/) {
                $jvm_xxarg = "-XX:+DTraceAllocProbes";
            }
            elsif ($probe_suffix =~ m/^(method_compile|compiled_method)/) {
                # Default here is much larger, this way our test doesn't need to
                # run as long.
                $jvm_xxarg = "-XX:CompileThreshold=100";
            }
            $stap_command = "$stap_command '$java_exec $jvm_xxarg staptest.SystemtapTester $probe_suffix'";
        }
        else {
            just_log("Probe $probe_name has no test defined.");
            $broken_count++;
            next;
        }
        $stap_command = "$stap_command | grep \"$probe_output\" 2>&1 >> /dev/null";
	print(".");
        just_log($stap_command);
        system($stap_command);
        if ($? == 0) {
            just_log("Probe $probe_name working.");
            $working_count++;
        }
        else {
            print("\n");
            log_and_print("Probe $probe_name failed.");
            $broken_count++;
        }
    }
    print("\n");
}

sub test_jstack {
    my ($stap_pre, $stap_script, $stap_post, $stap_command, $stap_result);
    my ($jargs) = @_;
    log_and_print("Testing if jstack works as expected with '$jargs'...");

    # Run staptest.SystemtapTester compiled_method_unload which does a lot
    # and can generate a somewhat "deep" stack.
    $stap_pre = "/usr/bin/stap " . join(' ', @tapset_dirs) . " -e '";
    $stap_post = "' -c '$java_exec $jargs staptest.SystemtapTester compiled_method_unload'";

    # Simple test jstack() should at least show our main method.
    # The test program runs the unloaded probe tester twice, pick the second
    # run to test output.
    $stap_script = "global hits = 0; probe hotspot.class_loaded { if (class == \"staptest/ClassUnloadedProbeTester\") { hits++; if (hits == 2) print_jstack(); } }";
    $stap_command = "$stap_pre $stap_script $stap_post";
    just_log($stap_command);
    print(".");
    $stap_result = `$stap_command`;
    just_log($stap_result);
    # Is our main method there?
    if ($? == 0 && $stap_result =~ /staptest\/SystemtapTester.main/) {
      $working_jstack++;
    } else {
      $broken_jstack++;
      print("\n");
      log_and_print("simple jstack failed.");
    }

    # Same, but with full stack (also internal hotspot frames) and signatures.
    $stap_script = "global hits = 0; probe hotspot.class_loaded { if (class == \"staptest/ClassUnloadedProbeTester\") { hits++; if (hits == 2) print_jstack_full(); } }";
    $stap_command = "$stap_pre $stap_script $stap_post";
    just_log($stap_command);
    print(".");
    $stap_result = `$stap_command`;
    just_log($stap_result);
    # We expect to find at least our URLClassLoader (plus correct signature)
    # in the backtrace.
    if ($? == 0 and $stap_result =~ /staptest\/StapURLClassLoader.loadClass\(Ljava\/lang\/String;\)Ljava\/lang\/Class;/) {
      $working_jstack++;
    } else {
      $broken_jstack++;
      print("\n");
      log_and_print("full jstack failed.");
    }

    print("\n");
}

# Output a tally of test results.
sub summarize {
    if ($working_count) {
        log_and_print("Working probes:     $working_count");
    }
    if ($broken_count) {
        log_and_print("Broken probes:     $broken_count");
    }
    if ($undetected_count) {
        log_and_print("Undetected probes:     $undetected_count");
    }
    if ($working_jstack) {
        log_and_print("Working jstack tests:     $working_jstack");
    }
    if ($broken_jstack) {
        log_and_print("Broken jstack tests:     $broken_jstack");
    }
}

# Any text that should follow a test run in the log file goes here.
sub log_postamble {
    if ($broken_count | $undetected_count | $broken_jstack) {
        log_and_print("Some tests did not work as expected.  See file " . 
            $logfile_name . " for details.");
    }
    just_log("End of test run");
}

# Remove compiled files and  close file handle(s).  Any other cleanup needed
#     should be added here.
sub clean_up {
    log_and_print("Removing compiled test files.");
    rmtree('staptest');
    unlink <*.o>;
    unlink <*.so>;
    unlink "JNIStapTest";
    if ($log_file) {
        close($log_file);
    }
}


# HELPER SUBROUTINES
#     Subroutines other than top-level.

# Used when processing arguments to set a number of variables that refer to
#     files/directories within $JAVA_HOME.
sub set_java_vars {
    my ($_java_home, $_arch_dir) = @_;
    $java_exec = "$_java_home/jre/bin/java";
    $javac_exec = "$_java_home/bin/javac";
    $jvm_dir = "$_java_home/jre/lib/$_arch_dir/server";
    $jvm_so = "$jvm_dir/libjvm.so";
    push(@include_dirs, "-I$_java_home/include");
    push(@include_dirs, "-I$_java_home/include/linux");
    die "Java executable not found: $java_exec\n" unless (-x $java_exec);
    die "Javac executable not found: $javac_exec\n" unless (-x $javac_exec);
    die "Directory not found: $jvm_dir\n" unless (-d $jvm_dir);
    die "File not found: $jvm_so\n" unless (-r $jvm_so);
    die "jni.h or jni_md.h headers not found within directory: $_java_home/j2sdk-image/include"
            unless ((-r "$_java_home/include/jni.h") &&
                    (-r "$_java_home/include/linux/jni_md.h"));
}

# When testing against an installed jdk, we need to know the current
#     architecture to find libjvm.so within the jdk directory tree.
sub get_arch_dir {
    my $sys_arch = $Config{archname};
    if ($sys_arch =~ m/x86_64/) {
        return "amd64";
    }
    elsif ($sys_arch =~ m/i.86/) {
        return "i386";
    }
    elsif ($sys_arch =~ m/alpha/) {
        return "alpha";
    }
    elsif ($sys_arch =~ m/arm/) {
        return "arm";
    }
    elsif ($sys_arch =~ m/mips-/) {
        return "mips";
    }
    elsif ($sys_arch =~ m/mipsel/) {
        return "mipsel";
    }
    elsif ($sys_arch =~ m/powerpc-/) {
        return "ppc";
    }
    elsif ($sys_arch =~ m/powerpc64/) {
        return "ppc64";
    }
    elsif ($sys_arch =~ m/sparc64/) {
        return "sparcv9";
    }
    elsif ($sys_arch =~ m/s390/) {
        return "s390";
    }
    else {
        die "Unknown arch: $sys_arch\n";
    }
}

# If we are logging, send arguments as lines to log file.
sub just_log {
    if ($log_file) {
        foreach my $line (@_) {
            print $log_file "$line\n";
        }
    }
}

# This is sort of like a "tee $logfile".
sub log_and_print {
    just_log(@_);
    foreach my $line (@_) {
        print("$line\n");
    }
}


# OVERRIDDEN FUNCTIONS

# Runs when --help option is passed, thanks to hooks in Getopt::Std::getopts();
sub main::HELP_MESSAGE {
    print("\n");
    print("To run test suite:\n");
    print("\n");
    print("   $ ./jstaptest.sh [[--help] | [<[-B <DIR> -A <ARCH>] | [-J <DIR>]> [-S <DIR>] [-<o|a> <LOGFILE>]]] -<p|j>\n");
    print("\n");
    print("--help will display this help message.\n");
    print("\n");
    print("\n");
    print("One of -BA or -J *must* be used.\n");
    print("\n");
    print("-J can be used to specify the location of the icedtea install on\n");
    print("    the system.  Specifically, this directory should contain the\n");
    print("    directories bin, jre, lib, and include.  Only the tapsets in\n");
    print("    systemtap's default directory will be tested.  Arch-specific\n");
    print("    directories will be determined from the system's arch.\n");
    print("\n");
    print("\n");
    print("-BA can be used to specify a local icedtea build.\n");
    print("    -B should be equivalent to the \$(BUILD_OUTPUT_DIR) in the\n");
    print("    icedtea Makefile.\n");
    print("    For example:\n");
    print("      ./jstaptest.sh -B \\\n");
    print("         /path/to/icedtea6/openjdk/build/<OS-ARCH>/\n");
    print("\n");
    print("    -A must also be used when -B is used, to specify the \n");
    print("    architecture of the icedtea build, \$(BUILD_ARCH_DIR) from\n");
    print("    the icedtea Makefile.\n");
    print("\n");
    print("\n");
    print("-S can be used to specify the directory where the test source\n");
    print("    code can be found.  If it is omitted, the current working\n");
    print("    directory is assumed.\n");
    print("\n");
    print("\n");
    print("-o or -a specify a log file for more detailed output.\n");
    print("    Using -o will replace the existing file if present, while -a\n");
    print("    will append.  These two options are mutually exclusive.  The\n");
    print("    log file will contain specifics of which probes pass, fail,\n");
    print("    or are not detected by systemtap, along with a record of\n");
    print("    the arguments passed to the script and the command executed\n");
    print("    for each test\n");
    print("\n");
    print("-p specifies that only the tapset probes should be tested.\n");
    print("-j specifies that only the jstack tapset should be tested.\n");
    print("Only one of -p or -j may be given. Both are tested by default.\n");
    print("\n");
    print("\n");
}

#######################################################################

