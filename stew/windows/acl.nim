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

type
  ACL {.pure, final.} = object
    aclRevision: uint8
    sbz1: uint8
    aclSize: uint16
    aceCount: uint16
    sbz2: uint16

  PACL* = ptr ACL

  SID* = object
    data: seq[byte]

  SD* = object
    sddata: seq[byte]
    acldata: seq[byte]

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

proc len*(sid: SID): int = len(sid.data)

proc getTokenInformation(token: uint,
                         information: uint32): IoResult[seq[byte]] =
  var tlength: uint32
  var buffer = newSeq[byte]()
  while true:
    let res =
      if len(buffer) == 0:
        getTokenInformation(token, information, nil, 0, tlength)
      else:
        getTokenInformation(token, information, cast[pointer](addr buffer[0]),
                            uint32(len(buffer)), tlength)
    if res != 0:
      return ok(buffer)
    else:
      let errCode = ioLastError()
      if errCode == ERROR_INSUFFICIENT_BUFFER:
        when sizeof(int) == 8:
          buffer.setLen(int(tlength))
        elif sizeof(int) == 4:
          if tlength > uint32(high(int)):
            return err(errCode)
          else:
            buffer.setLen(int(tlength))
      else:
        return err(errCode)

proc getCurrentUserSid*(): IoResult[SID] =
  ## Returns current process user's security identifier (SID).
  var token: uint
  let ores = openProcessToken(getCurrentProcess(), TOKEN_QUERY, token)
  if ores == 0:
    err(ioLastError())
  else:
    let tres = getTokenInformation(token, 1'u32)
    if tres.isErr():
      discard closeHandle(token)
      err(tres.error)
    else:
      var buffer = tres.get()
      var utoken = cast[ptr TOKEN_USER](addr buffer[0])
      let psid = utoken[].user.sid
      if isValidSid(psid) != 0:
        var ssid = newSeq[byte](getLengthSid(psid))
        if copySid(uint32(len(ssid)), addr ssid[0], psid) != 0:
          if closeHandle(token) != 0:
            ok(SID(data: ssid))
          else:
            err(ioLastError())
        else:
          let errCode = ioLastError()
          discard closeHandle(token)
          err(errCode)
      else:
        let errCode = ioLastError()
        discard closeHandle(token)
        err(errCode)

template getAddr*(sid: SID): pointer =
  ## Obtain Windows specific SID pointer.
  unsafeAddr sid.data[0]

proc createCurrentUserOnlyAcl(kind: SecDescriptorKind): IoResult[seq[byte]] =
  let aceMask = FILE_ALL_ACCESS
  var userSid = ? getCurrentUserSid()
  let size =
    ((sizeof(ACL) + sizeof(ACCESS_ALLOWED_ACE) + len(userSid)) +
      (sizeof(uint32) - 1)) and 0xFFFF_FFFC

  var buffer = newSeq[byte](size)
  var pdacl = cast[PACL](addr buffer[0])
  if initializeAcl(pdacl, uint32(size), ACL_REVISION) == 0:
    err(ioLastError())
  else:
    let aceFlags =
      if kind == Folder:
        OBJECT_INHERIT_ACE or CONTAINER_INHERIT_ACE
      else:
        0'u32
    if addAccessAllowedAceEx(pdacl, ACL_REVISION, aceFlags,
                             aceMask, userSid.getAddr()) == 0:
      err(ioLastError())
    else:
      ok(buffer)

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

  var buffer = ? createCurrentUserOnlyAcl(descriptorKind)
  var pdacl = cast[PACL](addr buffer[0])

  let dflags = DACL_SECURITY_INFORMATION or
               PROTECTED_DACL_SECURITY_INFORMATION
  let sres = setNamedSecurityInfo(newWideCString(path), SE_FILE_OBJECT,
                                  dflags, nil, nil, pdacl, nil)
  if sres != ERROR_SUCCESS:
    err(IoErrorCode(sres))
  else:
    ok()

proc createUserOnlySecurityDescriptor(kind: SecDescriptorKind): IoResult[SD] =
  var dacl = ? createCurrentUserOnlyAcl(kind)
  var buffer = newSeq[byte](SECURITY_DESCRIPTOR_MIN_LENGTH)
  if initializeSecurityDescriptor(addr buffer[0],
                                  SECURITY_DESCRIPTOR_REVISION) == 0:
    err(ioLastError())
  else:
    var res = SD(sddata: buffer, acldata: dacl)
    let bits = SE_DACL_PROTECTED
    if setSecurityDescriptorControl(addr res.sddata[0], bits, bits) == 0:
      err(ioLastError())
    else:
      if setSecurityDescriptorDacl(addr res.sddata[0], 1'i32,
                                   addr res.acldata[0], 0'i32) == 0:
        err(ioLastError())
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
  (len(sd.sddata) == 0) or (len(sd.acldata) == 0)

template getDescriptor*(sd: SD): pointer =
  ## Returns pointer to Windows specific security descriptor.
  cast[pointer](unsafeAddr sd.sddata[0])

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
