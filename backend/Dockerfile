FROM heroiclabs/nakama:3.20.0

COPY data/modules /nakama/data/modules
COPY render-entrypoint.sh /nakama/render-entrypoint.sh
RUN chmod +x /nakama/render-entrypoint.sh
ENTRYPOINT ["/nakama/render-entrypoint.sh"]