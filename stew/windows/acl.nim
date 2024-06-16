## Copyright (c) 2020 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements Windows specific procedure for security ACL
## management.
import ../io2
export io2

when not(defined(windows)):
  {.fatal: "This file should be imported only for Windows target!".}

const
  ERROR_INSUFFICIENT_BUFFER = 122'u32
  TOKEN_QUERY = 0x0008'u32
  ACL_REVISION = 0x0002'u32

  STANDARD_RIGHTS_REQUIRED = 0x000F_0000'u32
  SYNCHRONIZE = 0x0010_0000'u32
  FILE_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or 0x01FF'u32
  OBJECT_INHERIT_ACE = 0x0000_0001'u32
  CONTAINER_INHERIT_ACE = 0x0000_0002'u32
  DACL_SECURITY_INFORMATION = 0x0000_0004'u32
  PROTECTED_DACL_SECURITY_INFORMATION = 0x8000_0000'u32
  SE_FILE_OBJECT = 0x0000_0001'u32
  ERROR_SUCCESS = 0x0000_0000'u32
  ERROR_PATH_NOT_FOUND = 0x0000_0003'u32
  SECURITY_DESCRIPTOR_MIN_LENGTH = 40
  SECURITY_DESCRIPTOR_REVISION = 1'u32
  ACCESS_ALLOWED_ACE_TYPE = 0x00'u8
  SE_DACL_PROTECTED = 0x1000'u16
  LPTR = 0x0040'u32

type
  LocalMemPtr = distinct pointer

  ACL {.pure, final.} = object
    aclRevision: uint8
    sbz1: uint8
    aclSize: uint16
    aceCount: uint16
    sbz2: uint16

  PACL* = ptr ACL

  SID* = object
    data: LocalMemPtr

  SD* = object
    sddata: LocalMemPtr
    acldata: LocalMemPtr

  SID_AND_ATTRIBUTES {.pure, final.} = object
    sid: pointer
    attributes: uint32

  TOKEN_USER {.pure, final.} = object
    user: SID_AND_ATTRIBUTES

  ACE_HEADER {.pure, final.} = object
    aceType: byte
    aceFlags: byte
    aceSize: uint16

  ACCESS_ALLOWED_ACE {.pure, final.} = object
    header: ACE_HEADER
    mask: uint32
    sidStart: uint32

  SecDescriptorKind = enum
    File, Folder

proc closeHandle(hobj: uint): int32 {.
     importc: "CloseHandle", dynlib: "kernel32", stdcall, sideEffect.}
proc localAlloc(uFlags: uint32, ubytes: uint): pointer {.
     importc: "LocalAlloc", stdcall, dynlib: "kernel32".}
proc localFree(p: pointer): uint {.
     importc: "LocalFree", stdcall, dynlib: "kernel32".}
proc getCurrentProcess(): uint {.
     importc: "GetCurrentProcess", stdcall, dynlib: "kernel32", sideEffect.}
proc getTokenInformation(tokenHandle: uint, tokenInformationClass: uint32,
                       tokenInfo: pointer, tokenInfoLen: uint32,
                       returnLength: var uint32): int32 {.
     importc: "GetTokenInformation", stdcall, dynlib: "advapi32", sideEffect.}
proc openProcessToken(processHandle: uint, desiredAccess: uint32,
                      tokenHandle: var uint): int32 {.
     importc: "OpenProcessToken", stdcall, dynlib: "advapi32", sideEffect.}
proc equalSid(pSid1: pointer, pSid2: pointer): int32 {.
     importc: "EqualSid", dynlib: "advapi32", stdcall, sideEffect.}
proc getLengthSid(pSid: pointer): uint32 {.
     importc: "GetLengthSid", dynlib: "advapi32", stdcall, sideEffect.}
proc copySid(sidLength: uint32, dest: pointer, src: pointer): int32 {.
     importc: "CopySid", dynlib: "advapi32", stdcall, sideEffect.}
proc isValidSid(sid: pointer): int32 {.
     importc: "IsValidSid", dynlib: "advapi32", stdcall, sideEffect.}
proc setNamedSecurityInfo(pObjectName: WideCString, objectType: uint32,
                          securityInfo: uint32, psidOwner: pointer,
                          psidGroup: pointer, pDacl: PACL,
                          pSacl: PACL): uint32 {.
     importc: "SetNamedSecurityInfoW", dynlib: "advapi32", stdcall,
     sideEffect.}
proc getNamedSecurityInfo(pObjectName: WideCString, objectType: uint32,
                          securityInfo: uint32, ppsidOwner: ptr pointer,
                          ppsidGroup: ptr pointer, ppDacl: ptr PACL,
                          ppSacl: ptr PACL,
                          ppSecurityDescriptor: ptr pointer): uint32 {.
     importc: "GetNamedSecurityInfoW", stdcall, dynlib: "advapi32",
     sideEffect.}
proc setSecurityDescriptorDacl(pSD: pointer, bDaclPresent: int32,
                               pDacl: pointer,
                               bDaclDefaulted: int32): int32 {.
     importc: "SetSecurityDescriptorDacl", dynlib: "advapi32", stdcall,
     sideEffect.}
proc initializeAcl(pAcl: PACL, nAclLength: uint32,
                   dwAclRevision: uint32): int32 {.
     importc: "InitializeAcl", dynlib: "advapi32", stdcall, sideEffect.}
proc initializeSecurityDescriptor(pSD: pointer, dwRevision: uint32): int32 {.
     importc: "InitializeSecurityDescriptor", dynlib: "advapi32", stdcall,
     sideEffect.}
proc addAccessAllowedAceEx(pAcl: PACL, dwAceRevision: uint32,
                           aceFlags: uint32, accessMask: uint32,
                           psid: pointer): int32 {.
     importc: "AddAccessAllowedAceEx", dynlib: "advapi32", stdcall,
     sideEffect.}
proc getAce(pAcl: PACL, dwAceIndex: uint32, pAce: pointer): int32 {.
     importc: "GetAce", dynlib: "advapi32", stdcall, sideEffect.}
proc setSecurityDescriptorControl(pSD: pointer, bitsOfInterest: uint16,
                                  bitsToSet: uint16): int32 {.
     importc: "SetSecurityDescriptorControl", dynlib: "advapi32", stdcall,
     sideEffect.}

proc len*(sid: SID): int =
  int(getLengthSid(cast[pointer](sid.data)))

proc free(mem: LocalMemPtr): uint =
  localFree(cast[pointer](mem))

proc free*(sd: var SD) =
  ## Free memory occupied by security descriptor.
  discard sd.sddata.free()
  discard sd.acldata.free()
  sd.sddata = nil
  sd.acldata = nil

proc free*(sid: var SID) =
  ## Free memory occupied by security identifier.
  discard sid.data.free()
  sid.data = nil

proc getTokenInformation(token: uint,
                         information: uint32): IoResult[LocalMemPtr] =
  var
    tlength: uint32 = 0'u32
    localMem: pointer
  while true:
    let res =
      if tlength == 0'u32:
        getTokenInformation(token, information, nil, 0, tlength)
      else:
        getTokenInformation(token, information, localMem, tlength, tlength)
    if res != 0:
      return ok(LocalMemPtr(localMem))
    else:
      let errorCode = ioLastError()
      if errorCode == ERROR_INSUFFICIENT_BUFFER:
        when sizeof(int) == 8:
          localMem = localAlloc(LPTR, uint(tlength))
          if isNil(localMem):
            return err(ioLastError())
        elif sizeof(int) == 4:
          if tlength > uint32(high(int)):
            return err(errorCode)
          else:
            localMem = localAlloc(LPTR, uint(tlength))
            if isNil(localMem):
              return err(ioLastError())
      else:
        return err(errorCode)

proc getCurrentUserSid*(): IoResult[SID] =
  ## Returns current process user's security identifier (SID).
  var token: uint
  let ores = openProcessToken(getCurrentProcess(), TOKEN_QUERY, token)
  if ores == 0:
    err(ioLastError())
  else:
    let localMem = getTokenInformation(token, 1'u32).valueOr:
      discard closeHandle(token)
      return err(error)
    var utoken = cast[ptr TOKEN_USER](localMem)
    let psid = utoken[].user.sid
    if isValidSid(psid) != 0:
      let length = getLengthSid(psid)
      var ssid = localAlloc(LPTR, length)
      if isNil(ssid):
        return err(ioLastError())
      if copySid(uint32(length), ssid, psid) != 0:
        if closeHandle(token) != 0:
          if free(localMem) != 0'u:
            let errorCode = ioLastError()
            discard localFree(ssid)
            err(errorCode)
          else:
            ok(SID(data: LocalMemPtr(ssid)))
        else:
          let errorCode = ioLastError()
          discard localFree(ssid)
          err(errorCode)
      else:
        let errorCode = ioLastError()
        discard closeHandle(token)
        discard free(localMem)
        discard localFree(ssid)
        err(errorCode)
    else:
      let errorCode = ioLastError()
      discard closeHandle(token)
      discard free(localMem)
      err(errorCode)

template getAddr*(sid: SID): pointer =
  ## Obtain Windows specific SID pointer.
  cast[pointer](sid.data)

template getAddr*(mem: LocalMemPtr): pointer =
  cast[pointer](mem)

proc createCurrentUserOnlyAcl(kind: SecDescriptorKind): IoResult[LocalMemPtr] =
  let aceMask = FILE_ALL_ACCESS
  var userSid = ? getCurrentUserSid()
  let size =
    (uint32(sizeof(ACL) + sizeof(ACCESS_ALLOWED_ACE) + len(userSid)) +
      uint32(sizeof(uint32) - 1)) and 0xFFFF_FFFC'u32

  var localMem = localAlloc(LPTR, uint(size))
  if isNil(localMem):
    let errorCode = ioLastError()
    free(userSid)
    return err(errorCode)

  var pdacl = cast[PACL](localMem)
  if initializeAcl(pdacl, uint32(size), ACL_REVISION) == 0:
    let errorCode = ioLastError()
    discard localFree(localMem)
    free(userSid)
    err(errorCode)
  else:
    let aceFlags =
      if kind == Folder:
        OBJECT_INHERIT_ACE or CONTAINER_INHERIT_ACE
      else:
        0'u32
    if addAccessAllowedAceEx(pdacl, ACL_REVISION, aceFlags,
                             aceMask, userSid.getAddr()) == 0:
      let errorCode = ioLastError()
      discard localFree(localMem)
      free userSid
      err(errorCode)
    else:
      ok(LocalMemPtr(localMem))

proc setCurrentUserOnlyAccess*(path: string): IoResult[void] =
  ## Set file or folder with path ``path`` to be accessed only by current
  ## process' user. All other user's and user's group access will be
  ## prohibited.
  if not(fileAccessible(path, {})):
    return err(IoErrorCode(ERROR_PATH_NOT_FOUND))

  let descriptorKind =
    if isDir(path):
      Folder
    else:
      File

  let
    pacl = ? createCurrentUserOnlyAcl(descriptorKind)
    pdacl = cast[PACL](pacl)
    dflags = DACL_SECURITY_INFORMATION or
             PROTECTED_DACL_SECURITY_INFORMATION
    sres = setNamedSecurityInfo(newWideCString(path), SE_FILE_OBJECT,
                                dflags, nil, nil, pdacl, nil)

  if free(pacl) != 0'u:
    return err(ioLastError())
  if sres != ERROR_SUCCESS:
    err(IoErrorCode(sres))
  else:
    ok()

proc createUserOnlySecurityDescriptor(kind: SecDescriptorKind): IoResult[SD] =
  let
    dacl = ? createCurrentUserOnlyAcl(kind)
    localMem = localAlloc(LPTR, SECURITY_DESCRIPTOR_MIN_LENGTH)

  if isNil(localMem):
    discard free(dacl)
    return err(ioLastError())

  if initializeSecurityDescriptor(localMem, SECURITY_DESCRIPTOR_REVISION) == 0:
    let errorCode = ioLastError()
    discard free(dacl)
    discard localFree(localMem)
    err(errorCode)
  else:
    var res = SD(sddata: cast[LocalMemPtr](localMem), acldata: dacl)
    let bits = SE_DACL_PROTECTED
    if setSecurityDescriptorControl(localMem, bits, bits) == 0:
      let errorCode = ioLastError()
      discard free(dacl)
      discard localFree(localMem)
      err(errorCode)
    else:
      if setSecurityDescriptorDacl(localMem, 1'i32,
                                   res.acldata.getAddr(), 0'i32) == 0:
        let errorCode = ioLastError()
        discard free(dacl)
        discard localFree(localMem)
        err(errorCode)
      else:
        ok(res)

proc createFoldersUserOnlySecurityDescriptor*(): IoResult[SD] {.inline.} =
  ## Create security descriptor which can be used to restrict folder access to
  ## only the current process user.
  createUserOnlySecurityDescriptor(Folder)

proc createFilesUserOnlySecurityDescriptor*(): IoResult[SD] {.inline.} =
  ## Create security descriptor which can be used to restrict file access to
  ## only the current process user.
  createUserOnlySecurityDescriptor(File)

proc isEmpty*(sd: SD): bool =
  ## Returns ``true`` is security descriptor ``sd`` is not initialized.
  isNil(sd.sddata.getAddr()) or isNil(sd.acldata.getAddr())

template getDescriptor*(sd: SD): pointer =
  ## Returns pointer to Windows specific security descriptor.
  sd.sddata.getAddr()

proc checkCurrentUserOnlyACL*(path: string): IoResult[bool] =
  ## Check if specified file or folder ``path`` can be accessed and modified
  ## by current process' user only.
  var
    sdesc: pointer
    pdacl: PACL

  let userSid = ? getCurrentUserSid()
  let gres = getNamedSecurityInfo(newWideCString(path), SE_FILE_OBJECT,
                                  DACL_SECURITY_INFORMATION, nil, nil,
                                  addr pdacl, nil, addr sdesc)
  if gres != ERROR_SUCCESS:
    return err(IoErrorCode(gres))
  if isNil(pdacl):
    # Empty ACL
    if not(isNil(sdesc)):
      discard localFree(sdesc)
    ok(false)
  else:
    let aceCount = pdacl[].aceCount
    if aceCount != 1:
      if not(isNil(sdesc)):
        discard localFree(sdesc)
      ok(false)
    else:
      var ace: ptr ACCESS_ALLOWED_ACE
      if getAce(pdacl, uint32(0), cast[pointer](addr ace)) == 0:
        let errCode = ioLastError()
        if not(isNil(sdesc)):
          discard localFree(sdesc)
        err(errCode)
      else:
        let expectedFlags =
          if isDir(path):
            OBJECT_INHERIT_ACE or CONTAINER_INHERIT_ACE
          else:
            0x00'u32

        var psid = cast[pointer](addr ace.sidStart)
        if isValidSid(psid) != 0:
          if equalSid(psid, userSid.getAddr()) != 0:
            if ace[].header.aceType == ACCESS_ALLOWED_ACE_TYPE and
               ace[].header.aceFlags == expectedFlags and
               ace[].mask == FILE_ALL_ACCESS:
              ok(true)
            else:
              ok(false)
          else:
            ok(false)
        else:
          ok(false)
