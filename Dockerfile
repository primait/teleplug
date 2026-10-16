# We don't have 1.15.8...
FROM 279066465364.dkr.ecr.eu-west-1.amazonaws.com/prima-elixir:1.20.4

WORKDIR /code

USER app

COPY ["entrypoint", "/entrypoint"]

ENTRYPOINT ["/entrypoint"]
