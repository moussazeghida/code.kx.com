from distutils.core import setup, Extension, Distribution
from distutils.command.install_lib import install_lib
import os, sys
####

class QDistribution(Distribution):
    def finalize_options(self):
        self.cmdclass['install_lib'] = qinstall_lib
        self.qhome = os.getenv('QHOME') or os.path.join(os.getenv('HOME'), 'q')
        self.qarch = ('l32', 'l64')[sys.maxint > 2147483647]
        self.install_data = os.path.join(self.qhome, self.qarch)
        
class QExtension(Extension):
    pass

        

class qinstall_lib(install_lib):
    def install(self):
        dist = self.distribution
        qdst = os.path.join(dist.qhome, dist.qarch)
        # TODO: eliminate hard-coded names
        pyfiles = ['_k.so', 'q.py', 'qc.py']
        if os.path.isdir(self.build_dir):
            outfiles = [self.copy_file(os.path.join(self.build_dir, f),
                                       self.install_dir)[0] for f in pyfiles]
            outfiles += [self.copy_file(os.path.join(self.build_dir, 'py.so'), qdst)[0]]
        else:
            self.warn("'%s' does not exist" % self.build_dir)
            return
        return outfiles


python_lib_dir =  os.path.join(sys.exec_prefix, 'lib')
module_k = Extension('_k',
                     sources=[ '_k.c',],
                     extra_compile_args = ['-g'],
                     include_dirs = [ ],)
modulepy = QExtension('py',
                      sources=[ 'py.c',],
                      extra_compile_args = ['-g'],
                      runtime_library_dirs = [python_lib_dir],
                      )

setup(distclass=QDistribution,
      name='pyq',
      ext_modules=[ module_k, modulepy,],
      py_modules=['q','qc'],
      )
