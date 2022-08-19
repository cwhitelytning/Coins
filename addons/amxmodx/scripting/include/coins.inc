/**
 * Returns the number of coins the player has (If the player is not found returns -1).
 * @param   int id client index
 * @return  int
 */
native get_user_coins(id);

/**
 * Sets the specified number of coins to the player.
 * @param   int   id  client index
 * @param   count int number of coins
 * @return  bool
 */
native set_user_coins(id, number);

/**
 * Drops the specified number of coins from the player.
 * @param   int     id  client index
 * @param   number  int number of coins
 * @return  bool
 */
native user_drop_coins(id, number);

/**
 * Function is called at the time of changing the number of coins with the possibility of blocking.
 * For block, use return HC_SUPERCEDE or HC_BREAK, to ignore - HC_CONTINUE.
 * @param   int     id  client index
 * @param   count   int number of coins
 */
forward sc_give_coins_pre(id, count);

/**
 * Function is called when the number of coins changes.
 * @param   int     id  client index
 * @param   count   int number of coins
 */
forward sc_give_coins_post(id, count);

/**
 * Function is called at the moment of raising the coin with the possibility of blocking.
 * @param   int   id      client index
 * @param   int   entity  coin's entity index
 */
forward sc_coins_pickup_pre(id, entity);

/**
 * Function is called at the moment of raising the coin.
 * For block, use return HC_SUPERCEDE or HC_BREAK, to ignore - HC_CONTINUE.
 * @param   int   id      client index
 * @param   int   entity  coin's entity index
 */
forward sc_coins_pickup_post(id, entity);

/**
 * Function is called at the moment when a coin is attracted by a player with the possibility of blocking.
 * For block, use return HC_SUPERCEDE or HC_BREAK, to ignore - HC_CONTINUE.
 * @param   int   id      client index
 * @param   int   entity  coin's entity index
 */
forward sc_coin_pull(id, entity);