Welcome to "dswork"--a handful of scripts cobbled together by me 
(Carl Doersch) to automate a few tasks that I did so often I got 
tired of them, which eventually grew into a framework sophisticated
enough that now I can't live without it.  it is mainly (1) a 
persistence framework (it maps variables in your workspace 
to files on disk), and a distributed processing framework built 
on top of that persistence framework.  I find them useful, but 
your mileage may vary.  That said, relatively little of my time
has gone into testing this framework outside my use of it for
practically all of my research.  There are still some bugs and
unintuitive behaviors lurking around. 

dswork has only been tested in linux; it might work on Mac, and
probably won't work on Windows, as there are some bash scripts
and numerous calls to Matlab's 'unix' command.

The core of dswork is the global variable ds.  All of the data
stored in ds is mapped to the hard disk, in the folder specified
in ds.sys.outdir.  

dssetout: allows you to initialize ds.sys.outdir, automatically
          creating the directory specified and initializing dswork.

The mapping from the ds variable to the disk is interpreted as
follows.  

 - Any field that is a struct (and not an array of structs) becomes a directory; 
   naturally structs that are members of structs become directories
   inside directories.  The directory has the same name as the
   struct.
 - Any field that is a cell row vector becomes a directory with the same
   name, except with the characters '[]' appended.  Each element in
   the cell gets one file in that folder, which is simply the index
   plus the extension.  Empty values in cells are not saved.
 - Other fields simply map to single files.
 - ds.sys is a special structure and is not saved.

Cells and non-struct fields also have a type which is determined
by the suffix of the variable name.  YES, I said name; I found 
dealing with metadata was just too annoying.

 - variables ending in img are interpreted as images and
   will be saved in .jpg format. 
 - variables ending in fig are interpreted as matlab figure
   handles and saved as both a .jpg and a .pdf (in retrospect,
   saving as a .fig would have been more useful than .pdf).
   These cannot be loaded from disk.
 - variables ending in html are interpreted as text files and
   saved with the .html extension.
 - variables ending in _*txt, where * can refer to anything,
   are interpreted as text files and saved with an extension
   equal to whatever comes between the underscore and the "txt".
 - everything else just becomes a .mat file.

2-d cell arrays that don't have any of the reserved suffixes are 
treated in a special way that's only really useful in a distributed 
processing setting.  Each column is saved in its own file.  See details
below.

dssave: causes unsaved values in the ds variable to be written
        to disk.  dswork automatically keeps track of variables
        that have already been saved (including individual indexes
        in cell arrays) and will not save them.  
        
ds.sys.savestate keeps track of what has already been saved. Note 
that dswork cannot know when a variable is simply changed; to cause
a variable to be re-saved, you must alter the savestate so that
dswork believes the value has not been saved.  

dsup: Automates the process of updating ds.sys.savestate when a
      variable is updated.  

If you don't want a variable in your workspace, you can simply set
it to empty (making sure you don't change the type; i.e. assign {} to 
cell arrays, struct() to structs, and [] to everything else).

dsload: allows you to re-load variables from disk after they have been
        purged from memory.  Also allows you to load variables from
        a ds structure saved on disk that's not the one referenced
        in ds.sys.outdir.  In those cases, the resulting values are
        returned rather than being placed in the current dswork.

Finally, there are a few more helpful functions for dealing with files:

dsmv: allows you to rename variables and move them between structs,
      mirroring the changes on disk.

dssymlink: allows you to link a variable in dswork to another place
           on disk.  Particularly useful if you have a web server
           located on nfs for display, but want to keep your main
           files on a local disk.

dscd: change directory, such that the ds variable will now refer to
      a sub-structure of the ds.  This is useful for encapsulating
      functionality.

dspwd: print the current working directory.

For functions that take a path, the path can be specified in either
a relative form or an absolute form.  Absolute paths begin with
'.ds', and relative paths begin with simply 'ds'.  Paths may also
refer to sets of variables depending on the function.  When sets
make sense, specifying a variable that is a directory/struct will
generally cause the function to operate recursively on all fields
of that struct.  A '*' will be treated as a wildcard and cause the 
function to operate on all matching variables.  If the variable
is an array, including a set of braces at the end with indices will
cause the function to operate on those indices only: e.g.
dsload('ds.array1{1 2 3}') will load only indices 1, 2, and 3 of
ds.array1.

The distributed processing framework is built on top of all this.  

All of the inter-process communication is handled through the hard disk; 
dswork assumes that all processes will have access to the directory
specified in ds.sys.outdir.  I believe that sequential consistency (e.g.
Lustre) of write/read operations, or close-to-open consistency (e.g. nfs) are sufficient
for dswork to function correctly.  More relaxed consistency models may 
work as well, but they have not been tested.  This has been tested on nfs
and Lustre; Lustre works well, nfs usually works well but sometimes writes can
take a very long time to propagate, and a single client not propagating its 
results can lead to arbitrarily long waiting times where nothing is being
accomplished.  

dsmapredopen: Allows you to open a distributed processing session. This can
              either be done with local workers or with workers distributed
              across machines.  Hopefully using local workers will work out of
              the box; distributed workers require that you configure/rewrite
              dsmapredopen such that it submits jobs to run on the machines.
              See the documentation for dsmapredopen for details on how to
              set up your cluster to use dswork.


dsmapredclose: Close a session opened by dsmapredopen.

Note that the MATLAB worker processes will re-spawn if you kill them!  It's best
to use dsmapredclose.  Note you can use dsinterrupt to force them to stop (though
dsinterrupt by itself doesn't wait for the interrupts to actually take effect). If you've
lost the master, touch the file 'exit' in the [ds.sys.outdir '/ds/sys/distproc']
directory and they will exit after about one minute (if they aren't running anything).
If even that doesn't work, you need to kill the qsubfile*.sh's first (something like 
killall -r .*qsubfile.*sh on each machine) before killing the matlab processes.  

dsrundistributed: This is the core function of the distributed processing
                  framework.  You specify a command to run, and either a 
                  field of the ds variable whose data will be mapped to 
                  the worker threads, or simply an integer specifying the
                  number of jobs to run.

dsmapreduce: Essentially the equivalent of two consecutive calls to 
             dsrundistributed, but additionally
             allows you to specify one or more special 'mapreduce' variables.
             During the first round, each job is assumed to write one or more
             columns of these variables, and then on the reduce phase, each
             job will read exactly one row.  Communication through this variable
             is done over ssh reasonably efficiently (i.e. there is a persistent
             connection).  The mapreduce variables will be deleted at the end
             of the dsmapreduce.

dssetlocaldir: set the local directory where dswork can cache files on each
               machine before sending them over ssh.

Note that the 2-d cell array approach can allow you to efficiently build 
something that behaves like mapreduce out of two dsrundistributed calls.  
For the first call to dsmapreduce, each distributed job fills
in one column of a variable, and thus writes only one file (calls to open
a file for writing are generally very expensive).  The next
dsmapreduce reads one row of this variable.  This will perform much
better than writing each cell separately, since there will be fewer
file open operations.

Finally, dswork is designed for debugging misbehaving scripts.  Logs
are kept in [ds.sys.outdir '/sys/distproc/output' MACHINE_ID '.log'].
Furthermore, if you interrupt the execution (with ctrl+C), you will be given 
the option to drop to a command line and run individual jobs locally.  This
feature works, but it is very experimental; if you interrupt a script
and then continue the execution of the distributed session, the session 
may not complete properly, and rolling back the session may not correctly
roll back the variables that distributed workers wrote.
