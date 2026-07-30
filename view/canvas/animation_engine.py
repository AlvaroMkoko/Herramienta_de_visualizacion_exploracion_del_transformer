from PySide6.QtQuick import QQuickFramebufferObject
from PySide6.QtCore import Slot
from vispy import gloo
import numpy as np
from OpenGL import GL

class VispyRenderer(QQuickFramebufferObject.Renderer):

    def __init__(self):
        super().__init__()

        self.matrix = np.array([
            [0,1,0,1],
            [1,1,0,0],
            [0,0,1,1],
            [1,0,1,0]
        ], dtype=np.float32)


    def render(self):

        # # Aquí ocurre el render OpenGL
        # gloo.clear("black")

        # # Aquí después dibujarías tu matriz,
        # # shaders, imágenes, puntos, etc.

        # self.update()
        # GL.glClearColor(
        #     1.0,
        #     0.0,
        #     0.0,
        #     1.0
        # )

        # GL.glClear(
        #     GL.GL_COLOR_BUFFER_BIT
        # )

        self.update()


    def synchronize(self, item):

        # Comunicación entre QML y Renderer

        self.matrix = item.matrix



class VispyItem(QQuickFramebufferObject):

    def __init__(self):
        super().__init__()

        self.matrix = np.array([])
        self.setTextureFollowsItemSize(True)
        print("VispyItem creado")
        self.update()

    def createRenderer(self):
        print("ljsdfjlsdjf llaalaas")
        return VispyRenderer()


    @Slot(list)
    def setMatrix(self, matrix):
        print("jfksjdfls")  
        self.matrix = np.array(matrix)  
        self.update()