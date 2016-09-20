FROM haproxy:latest

RUN 'apt' 'update'
RUN 'apt' 'install' '-y' 'curl'
