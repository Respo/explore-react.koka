module library/maybe

pub fun and-then(m : maybe<a>, next : a -> e maybe<b>) : e maybe<b>
  match m
    Just(value) -> next(value)
    Nothing -> Nothing

pub fun or-else(m : maybe<a>, next : () -> e maybe<a>) : e maybe<a>
  match m
    Just(_) -> m
    Nothing -> next()

pub fun unwrap-or-else(m : maybe<a>, next : () -> e a) : e a
  match m
    Just(value) -> value
    Nothing -> next()