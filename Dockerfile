# We don't have 1.15.8...
FROM public.ecr.aws/primaassicurazioni/elixir:1.15.7-1

WORKDIR /code

USER app

COPY ["entrypoint", "/entrypoint"]

ENTRYPOINT ["/entrypoint"]
