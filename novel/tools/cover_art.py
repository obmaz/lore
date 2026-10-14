"""Validate and embed the shared, explicitly proposed generated cover artwork."""
import base64
import hashlib
import struct
from materials import ROOT, read

PLAN=ROOT/'writing/covers/manifest.json'


def jpeg_size(body):
    if body[:2]!=b'\xff\xd8':raise ValueError('cover is not a JPEG')
    offset=2
    while offset<len(body):
        if body[offset]!=255:raise ValueError('invalid JPEG marker')
        while body[offset]==255:offset+=1
        marker=body[offset];offset+=1
        length=struct.unpack('>H',body[offset:offset+2])[0]
        if marker in (192,193,194):
            height,width=struct.unpack('>HH',body[offset+3:offset+7]);return width,height
        offset+=length
    raise ValueError('JPEG has no frame size')


def load_covers(document=None):
    plan=read(PLAN) if document is None else document
    if plan['version']!=1 or plan['shared_editions']!=['A','B'] or set(plan['images'])!={'main','chapter01','chapter02','chapter03'}:
        raise ValueError('exactly four shared cover images are required')
    for key,image in plan['images'].items():
        path=(ROOT/image['file']).resolve()
        if not path.is_relative_to(ROOT/'writing/covers') or path.suffix!='.jpg' or image['mime_type']!='image/jpeg':
            raise ValueError('cover path escapes its package')
        body=path.read_bytes()
        if hashlib.sha256(body).hexdigest()!=image['sha256']:raise ValueError('cover image hash changed')
        width,height=jpeg_size(body)
        if (width,height)!=(image['width'],image['height']) or width*3!=height*2:
            raise ValueError('cover dimensions or 2:3 ratio changed')
        if image['chapter_id']!=(None if key=='main' else key):raise ValueError('cover chapter identity differs')
        if image['origin']!='authored' or image['status']!='proposed' or not image['metadata']['addition']:
            raise ValueError('cover illustration must be marked noncanonical')
    return plan


def cover_inputs():
    plan=load_covers()
    return [PLAN,ROOT/'tools/cover_art.py',*[ROOT/i['file']for i in plan['images'].values()]]


def public_covers(display):
    plan=load_covers()
    return {'revision':plan['revision'],'title':display(plan['book_title']),
            'subtitle':display(plan['book_subtitle']),
            'images':{key:{'src':'data:image/jpeg;base64,'+base64.b64encode((ROOT/i['file']).read_bytes()).decode(),
                          'alt':display(i['alt']),'width':i['width'],'height':i['height']}
                      for key,i in plan['images'].items()}}
