'use client'

import { useEffect, useState } from 'react'

export function UserDisplay() {
  const [name, setName] = useState('')
  useEffect(() => {
    const match = document.cookie.match(/(?:^|;\s*)userName=([^;]*)/)
    if (match) setName(decodeURIComponent(match[1]))
  }, [])
  return <>{name || 'Cửa hàng'}</>
}
