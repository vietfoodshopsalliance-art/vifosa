export type Role = 'admin' | 'store_owner' | 'mod'

export interface Me {
  _id: string
  username: string
  email?: string
  phone?: string
  roles: Role[]
  storeId?: string
}

export function hasRole(me: Me, ...roles: Role[]): boolean {
  return roles.some((r) => me.roles.includes(r))
}

export function isAdmin(me: Me): boolean {
  return me.roles.includes('admin')
}

export function isStoreUser(me: Me): boolean {
  return me.roles.includes('store_owner') || me.roles.includes('mod')
}

export function isMod(me: Me): boolean {
  return me.roles.includes('mod')
}
