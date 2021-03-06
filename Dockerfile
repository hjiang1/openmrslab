FROM jupyter/scipy-notebook:619e9cc2fc07

MAINTAINER Ben Rowland "bennyrowland@mac.com"

USER root

# cmake is used to build niftyreg
# gnupg2 is necessary to add the neurodebian apt-key to install fsl
# libxml2 and libxslt1 are for Tarquin
RUN apt-get update \
    && apt-get install -y cmake gnupg2 libxml2-dev libxslt1-dev

# this seems to be important to prevent adding the key (below) failing sometimes
# https://github.com/f-secure-foundry/usbarmory-debian-base_image/issues/9#issuecomment-451635505
RUN mkdir ~/.gnupg
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

RUN wget -O- http://neuro.debian.net/lists/bionic.de-m.full | sudo tee /etc/apt/sources.list.d/neurodebian.sources.list && \
    sudo apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9

# install fsl
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install fsl-core \
    # Run configuration script for normal usage
    && echo ". /etc/fsl/5.0/fsl.sh" >> /home/jovyan/.bashrc
# Configure environment
ENV FSLDIR=/usr/share/fsl/5.0/
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=$PATH:/usr/lib/fsl/5.0
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/fsl/5.0

RUN mkdir /opt/niftyreg-src && \
    mkdir /opt/niftyreg-build && \
    git clone https://cmiclab.cs.ucl.ac.uk/mmodat/niftyreg.git /opt/niftyreg-src
WORKDIR /opt/niftyreg-build
RUN PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && \
    cmake -D CMAKE_BUILD_TYPE=Release /opt/niftyreg-src && \
    make && \
    make install && \
    PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/fsl/5.0

# install tarquin
RUN wget --quiet https://sourceforge.net/projects/tarquin/files/TARQUIN_4.3.10/TARQUIN_Linux_4.3.10.tar.gz/download -O /tmp/tarquin.tar.gz && \
    mkdir /etc/tarquin && \
    tar -zxvf /tmp/tarquin.tar.gz -C /etc/tarquin --strip-components=1
ENV PATH /etc/tarquin:$PATH

# copy the examples directory in to the notebook root and change the owner
COPY ./examples /home/$NB_USER/work/examples/
RUN chown $NB_USER -R /home/$NB_USER/work/examples/

USER $NB_USER
WORKDIR /home/jovyan/work

RUN conda update -n base conda && \
    pip install --upgrade pip && \
    pip install pyx nipype pydicom pylcmodel==0.3.3


RUN git clone https://github.com/openmrslab/suspect.git /home/jovyan/suspect && \
    pip install suspect==0.4.1

# we create a Python2 environment which is necessary for pygamma
RUN conda create --quiet --yes -p $CONDA_DIR/envs/python2 python=2.7 ipython ipykernel kernda backports.functools_lru_cache && \
    conda clean -tipsy
USER root
# Create a global kernelspec in the image and modify it so that it properly activates
# the python2 conda environment.
RUN $CONDA_DIR/envs/python2/bin/python -m ipykernel install && \
    $CONDA_DIR/envs/python2/bin/kernda -o -y /usr/local/share/jupyter/kernels/python2/kernel.json

USER $NB_USER
RUN /bin/bash -c "source activate python2 && pip install pygamma"


